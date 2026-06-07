module ApplicationHelper
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
