module AjaxfulRating # :nodoc:
  class StarsBuilder # :nodoc:
    include AjaxfulRating::Locale
    
    attr_reader :rateable, :user, :options, :remote_options
    
    def initialize(rateable, user_or_static, template, css_builder, options = {}, remote_options = {})
      @user = user_or_static unless user_or_static == :static
      @rateable, @template, @css_builder = rateable, template, css_builder
      apply_stars_builder_options!(options, remote_options)
    end
    
    def show_value
      if options[:show_user_rating]
        rate = rateable.rate_by(user, options[:dimension]) if user
        rate ? rate.stars : 0
      else
        rateable.rate_average(true, options[:dimension])
      end
    end
    
    def render
      value = show_value
      (options[:wrap] ? wrapper_tag(value) : ratings_tag(value)) << (options[:show_chosen] ? ratings_chosen(value) : nil)
    end
    
    private
    
    def apply_stars_builder_options!(options, remote_options)
      @options = {
        :wrap => true,
        :small => false,
        :show_user_rating => false,
        :force_static => false,
        :show_chosen => false,
        :normalize => false,
        :current_user => (@template.current_user if @template.respond_to?(:current_user))
      }.merge(options)
      
      @options[:small] = @options[:small].to_s == 'true'
      @options[:show_user_rating] = @options[:show_user_rating].to_s == 'true'
      @options[:wrap] = @options[:wrap].to_s == 'true'
      
      @remote_options = {
        :url => nil,
        :method => :post
      }.merge(remote_options)
      
      if @remote_options[:url].nil?
        rateable_name = ActionController::RecordIdentifier.dom_class(rateable)
        url = "rate_#{rateable_name}_path"
        if @template.respond_to?(url)
          @remote_options[:url] = @template.send(url, rateable)
        else
          raise(Errors::MissingRateRoute)
        end
      end
    end
    
    def ratings_tag(value=show_value)
      stars = []
      if options[:normalize]
        max = rateable.class.max_stars
        value = (max * value).to_f/rateable.class.max_stars(options[:dimension])
      else
        max = rateable.class.max_stars(options[:dimension])
      end

      width = (value / max.to_f) * 100
      li_class = "axr-#{value}-#{max}".gsub('.', '_')
      @css_builder.rule(".max-#{max}-stars", :width => (max * 25),
                        :margin_right => ((rateable.class.max_stars-max)) * 25)
      @css_builder.rule(".max-#{max}-stars.small",
        :width => (max * 10),
        :margin_right => ((rateable.class.max_stars-max) * 25)) if options[:small]
      
      stars << @template.content_tag(:li, i18n(:current, value, options[:dimension]), :class => "show-value",
        :style => "width: #{width}%", :title => i18n(:hover, value, options[:dimension]))
      stars += (1..max).map do |i|
        star_tag(i,max)
      end
      @template.content_tag(:ul, stars.join.html_safe, :class => "ajaxful-rating#{' small' if options[:small]} max-#{max}-stars")
    end

    def ratings_chosen(value=show_value)
      @template.content_tag(:div, @template.content_tag(:div, i18n(:hover, value, options[:dimension]), :class => "ajaxful-rating-chosen"), :class => "ajaxful-rating-chosen-wrapper")
    end

    def star_tag(value,max)
      already_rated = rateable.rated_by?(user, options[:dimension]) if user && !rateable.axr_config(options[:dimension])[:allow_update]
      css_class = "stars-#{value}-#{max}"
      @css_builder.rule(".ajaxful-rating .#{css_class}", {
        :width => "#{(value / max.to_f) * 100}%",
        :zIndex => (max + 2 - value).to_s
      })

      @template.content_tag(:li) do
        if !options[:force_static] && !already_rated && user && options[:current_user] == user
          link_star_tag(value, css_class)
        else
          @template.content_tag(:span, value, :class => css_class, :title => i18n(:current, value, options[:dimension]))
        end
      end
    end

    def link_star_tag(value, css_class)
      query = {
        :stars => value,
        :dimension => options[:dimension],
        :small => options[:small],
        :show_user_rating => options[:show_user_rating]
      }.to_query

      dimension = options[:dimension]
      wrapper_id = rateable.wrapper_dom_id(options)

      options = {
        :class => css_class,
        :title => i18n(:hover, value, dimension),
        :method => remote_options[:method] || :post,
        :remote => true
        #:onmouseover => "$('\##{wrapper_id}').find('.ajaxful-rating-chosen').text('#{i18n(:hover, value, dimension)}')",
        #:onmouseout => "$('\##{wrapper_id}').find('.ajaxful-rating-chosen').text('#{i18n(:no_ratings, dimension)}')",
        #:onclick => "$('\##{wrapper_id}').find('.ajaxful-rating-chosen').text('#{i18n(:hover, value, dimension)}')"
      }

      href = "#{remote_options[:url]}?#{query}"

      @template.link_to(value, href, options)
    end

    def wrapper_tag(value=show_value)
      @template.content_tag(:div, ratings_tag, :class => "ajaxful-rating-wrapper",
        :id => rateable.wrapper_dom_id(options))
    end
  end
end
