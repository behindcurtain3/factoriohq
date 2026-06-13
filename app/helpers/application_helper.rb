module ApplicationHelper
  # Renders an optional extension partial (app/views/hooks/_<name>) when one
  # is defined, e.g. by an engine layering extra features onto this app;
  # renders nothing otherwise.
  def render_hook(name, **locals)
    partial = "hooks/#{name}"
    return unless lookup_context.exists?(partial, [], true)

    render(partial, **locals)
  end

  def registrations_enabled?
    SiteSetting.get("registrations_enabled", "true") == "true"
  end

  def markdown(text)
    return "" if text.blank?

    # Use Redcarpet to parse the markdown text
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, filter_html: true)
    options = {
      autolink: true,
      superscript: true,
      strikethrough: true,
      no_intra_emphasis: true,
      tables: true
    }
    markdown = Redcarpet::Markdown.new(renderer, options)

    # Render the markdown text to HTML
    html_content = markdown.render(text)

    # Sanitize the HTML content to prevent XSS attacks
    sanitized_content = sanitize(html_content, tags: %w[a p img h1 h2 h3 h4 h5 h6 blockquote ul ol li code pre], attributes: %w[href src alt title])

    sanitized_content.html_safe
  end
end
