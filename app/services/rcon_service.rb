require "socket"

# Minimal Valve Source RCON client. Factorio speaks this protocol on its
# --rcon-port. Packets are little-endian and framed as:
#   [int32 size][int32 id][int32 type][body bytes][0x00][0x00]
# where `size` counts everything after itself (id + type + body + 2 nulls).
class RconService
  class RconError < StandardError; end

  SERVERDATA_AUTH = 3
  SERVERDATA_AUTH_RESPONSE = 2
  SERVERDATA_EXECCOMMAND = 2
  SERVERDATA_RESPONSE_VALUE = 0

  def initialize(host, port, password, timeout: 5)
    @host = host
    @port = port
    @password = password
    @timeout = timeout
    @request_id = 0
  end

  # Connect, authenticate, run a single command, and return its response body.
  # Raises RconError on any failure (connection, auth, or timeout).
  def execute(command)
    connect
    authenticate
    run(command)
  ensure
    disconnect
  end

  def connect
    @socket = Socket.tcp(@host, @port, connect_timeout: @timeout)
  rescue => e
    raise RconError, "Could not connect to #{@host}:#{@port} (#{e.message})"
  end

  def disconnect
    @socket&.close
  rescue IOError
    # already closed
  ensure
    @socket = nil
  end

  def authenticate
    request_id = send_packet(SERVERDATA_AUTH, @password)
    packet = read_auth_response
    if packet.nil? || packet[:id] == -1 || packet[:id] != request_id
      raise RconError, "Authentication failed (is the RCON password correct?)"
    end
  end

  def run(command)
    send_packet(SERVERDATA_EXECCOMMAND, command)
    packet = read_packet
    raise RconError, "No response received from server" unless packet

    packet[:body]
  end

  private

  # A server may emit an empty RESPONSE_VALUE before the AUTH_RESPONSE, so read
  # a couple of packets looking for the auth response.
  def read_auth_response
    2.times do
      packet = read_packet
      return packet if packet.nil? || packet[:type] == SERVERDATA_AUTH_RESPONSE
    end
    nil
  end

  def next_request_id
    @request_id += 1
  end

  # Returns the request id used, so the caller can match the response.
  def send_packet(type, body)
    id = next_request_id
    payload = [ id, type ].pack("VV") + body.to_s.b + "\x00\x00".b
    write_all([ payload.bytesize ].pack("V") + payload)
    id
  end

  def write_all(data)
    offset = 0
    while offset < data.bytesize
      raise RconError, "Timed out sending data" unless IO.select(nil, [ @socket ], nil, @timeout)

      written = @socket.write_nonblock(data.byteslice(offset..-1), exception: false)
      offset += written if written.is_a?(Integer)
    end
  rescue RconError
    raise
  rescue => e
    raise RconError, "Send error: #{e.message}"
  end

  def read_packet
    header = read_exactly(4)
    return nil unless header

    size = header.unpack1("V")
    return nil if size < 10 || size > 8192 # 10 = id + type + 2 nulls; sanity bound

    payload = read_exactly(size)
    return nil unless payload

    id, type = payload.unpack("VV")
    body = payload.byteslice(8, size - 10).to_s.force_encoding("UTF-8")
    { id: id, type: type, body: body }
  end

  def read_exactly(count)
    buffer = +"".b
    while buffer.bytesize < count
      raise RconError, "Timed out reading from server" unless IO.select([ @socket ], nil, nil, @timeout)

      chunk = @socket.read_nonblock(count - buffer.bytesize, exception: false)
      case chunk
      when :wait_readable then next
      when nil then return nil # EOF / connection closed
      else buffer << chunk
      end
    end
    buffer
  end
end
