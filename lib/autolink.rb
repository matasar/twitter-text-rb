module Twitter
  # A module for including Tweet auto-linking in a class. The primary use of this is for helpers/views so they can auto-link
  # usernames, lists, hashtags and URLs.
  module Autolink extend self
    include ActionView::Helpers::TagHelper #tag_options needed by auto_link

    # Default CSS class for auto-linked URLs
    DEFAULT_URL_CLASS = "tweet-url"
    # Default CSS class for auto-linked lists (along with the url class)
    DEFAULT_LIST_CLASS = "list-slug"
    # Default CSS class for auto-linked usernames (along with the url class)
    DEFAULT_USERNAME_CLASS = "username"
    # Default CSS class for auto-linked hashtags (along with the url class)
    DEFAULT_HASHTAG_CLASS = "hashtag"
    # Default target for auto-linked urls (nil will not add a target attribute)
    DEFAULT_TARGET = nil
    # HTML attribute for robot nofollow behavior (default)
    HTML_ATTR_NO_FOLLOW = " rel=\"nofollow\""

    HTML_ENTITIES = {
      '&' => '&amp;',
      '>' => '&gt;',
      '<' => '&lt;',
      '"' => '&quot;',
      "'" => '&#39;'
    }

    def html_escape(text)
      text && text.gsub(/[&"'><]/) do |character|
        HTML_ENTITIES[character]
      end
    end

    # Add <tt><a></a></tt> tags around the usernames, lists, hashtags and URLs in the provided <tt>text</tt>. The
    # <tt><a></tt> tags can be controlled with the following entries in the <tt>options</tt>
    # hash:
    #
    # <tt>:url_class</tt>::     class to add to all <tt><a></tt> tags
    # <tt>:list_class</tt>::    class to add to list <tt><a></tt> tags
    # <tt>:username_class</tt>::    class to add to username <tt><a></tt> tags
    # <tt>:hashtag_class</tt>::    class to add to hashtag <tt><a></tt> tags
    # <tt>:username_url_base</tt>::      the value for <tt>href</tt> attribute on username links. The <tt>@username</tt> (minus the <tt>@</tt>) will be appended at the end of this.
    # <tt>:list_url_base</tt>::      the value for <tt>href</tt> attribute on list links. The <tt>@username/list</tt> (minus the <tt>@</tt>) will be appended at the end of this.
    # <tt>:hashtag_url_base</tt>::      the value for <tt>href</tt> attribute on hashtag links. The <tt>#hashtag</tt> (minus the <tt>#</tt>) will be appended at the end of this.
    # <tt>:suppress_lists</tt>::    disable auto-linking to lists
    # <tt>:suppress_no_follow</tt>::   Do not add <tt>rel="nofollow"</tt> to auto-linked items
    # <tt>:target</tt>::   add <tt>target="window_name"</tt> to auto-linked items
    def auto_link(text, options = {})
      auto_link_usernames_or_lists(
        auto_link_urls_custom(
          auto_link_hashtags(text, options),
        options),
      options)
    end

    # Add <tt><a></a></tt> tags around the usernames and lists in the provided <tt>text</tt>. The
    # <tt><a></tt> tags can be controlled with the following entries in the <tt>options</tt>
    # hash:
    #
    # <tt>:url_class</tt>::     class to add to all <tt><a></tt> tags
    # <tt>:list_class</tt>::    class to add to list <tt><a></tt> tags
    # <tt>:username_class</tt>::    class to add to username <tt><a></tt> tags
    # <tt>:username_url_base</tt>::      the value for <tt>href</tt> attribute on username links. The <tt>@username</tt> (minus the <tt>@</tt>) will be appended at the end of this.
    # <tt>:list_url_base</tt>::      the value for <tt>href</tt> attribute on list links. The <tt>@username/list</tt> (minus the <tt>@</tt>) will be appended at the end of this.
    # <tt>:suppress_lists</tt>::    disable auto-linking to lists
    # <tt>:suppress_no_follow</tt>::   Do not add <tt>rel="nofollow"</tt> to auto-linked items
    # <tt>:target</tt>::   add <tt>target="window_name"</tt> to auto-linked items
    def auto_link_usernames_or_lists(text, options = {}) # :yields: list_or_username
      options = options.dup
      options[:url_class] ||= DEFAULT_URL_CLASS
      options[:list_class] ||= DEFAULT_LIST_CLASS
      options[:username_class] ||= DEFAULT_USERNAME_CLASS
      options[:username_url_base] ||= "http://twitter.com/"
      options[:list_url_base] ||= "http://twitter.com/"
      options[:target] ||= DEFAULT_TARGET

      extra_html = HTML_ATTR_NO_FOLLOW unless options[:suppress_no_follow]
      new_text = ""

      # this -1 flag allows strings ending in ">" to work
      text.split(/[<>]/, -1).each_with_index do |chunk, index|
        if index != 0
          new_text << ((index % 2 == 0) ? ">" : "<")
        end

        if index % 4 != 0
          new_text << chunk
        else
          new_text << chunk.gsub(Twitter::Regex[:auto_link_usernames_or_lists]) do
            before, at, user, slash_listname, after = $1, $2, $3, $4, $'
            if slash_listname && !options[:suppress_lists]
              # the link is a list
              chunk = list = "#{user}#{slash_listname}"
              chunk = yield(list) if block_given?
              "#{before}#{at}<a class=\"#{options[:url_class]} #{options[:list_class]}\" #{target_tag(options)}href=\"#{html_escape(options[:list_url_base])}#{html_escape(list.downcase)}\"#{extra_html}>#{html_escape(chunk)}</a>"
            else
              if after =~ Twitter::Regex[:end_screen_name_match]
                # Followed by something that means we don't autolink
                "#{before}#{at}#{user}#{slash_listname}"
              else
                # this is a screen name
                chunk = user
                chunk = yield(chunk) if block_given?
                "#{before}#{at}<a class=\"#{options[:url_class]} #{options[:username_class]}\" #{target_tag(options)}href=\"#{html_escape(options[:username_url_base])}#{html_escape(chunk)}\"#{extra_html}>#{html_escape(chunk)}</a>"
              end
            end
          end
        end
      end
      new_text
    end

    # Add <tt><a></a></tt> tags around the hashtags in the provided <tt>text</tt>. The
    # <tt><a></tt> tags can be controlled with the following entries in the <tt>options</tt>
    # hash:
    #
    # <tt>:url_class</tt>::     class to add to all <tt><a></tt> tags
    # <tt>:hashtag_class</tt>:: class to add to hashtag <tt><a></tt> tags
    # <tt>:hashtag_url_base</tt>::      the value for <tt>href</tt> attribute. The hashtag text (minus the <tt>#</tt>) will be appended at the end of this.
    # <tt>:suppress_no_follow</tt>::   Do not add <tt>rel="nofollow"</tt> to auto-linked items
    # <tt>:target</tt>::   add <tt>target="window_name"</tt> to auto-linked items
    def auto_link_hashtags(text, options = {})  # :yields: hashtag_text
      options = options.dup
      options[:url_class] ||= DEFAULT_URL_CLASS
      options[:hashtag_class] ||= DEFAULT_HASHTAG_CLASS
      options[:hashtag_url_base] ||= "http://twitter.com/search?q=%23"
      options[:target] ||= DEFAULT_TARGET
      extra_html = HTML_ATTR_NO_FOLLOW unless options[:suppress_no_follow]

      text.gsub(Twitter::Regex[:auto_link_hashtags]) do
        before = $1
        hash = $2
        text = $3
        text = yield(text) if block_given?
        "#{before}<a href=\"#{options[:hashtag_url_base]}#{html_escape(text)}\" title=\"##{html_escape(text)}\" #{target_tag(options)}class=\"#{options[:url_class]} #{options[:hashtag_class]}\"#{extra_html}>#{html_escape(hash)}#{html_escape(text)}</a>"
      end
    end

    # Add <tt><a></a></tt> tags around the URLs in the provided <tt>text</tt>. Any
    # elements in the <tt>href_options</tt> hash will be converted to HTML attributes
    # and place in the <tt><a></tt> tag. Unless <tt>href_options</tt> contains <tt>:suppress_no_follow</tt>
    # the <tt>rel="nofollow"</tt> attribute will be added.
    def auto_link_urls_custom(text, href_options = {})
      options = href_options.dup
      options[:rel] = "nofollow" unless options.delete(:suppress_no_follow)

      text.gsub(Twitter::Regex[:valid_url]) do
        all, before, url, protocol, domain, path, query_string = $1, $2, $3, $4, $5, $6, $7
        if !protocol.blank?
          html_attrs = tag_options(options.stringify_keys) || ""
          "#{before}<a href=\"#{html_escape(url)}\"#{html_attrs}>#{html_escape(url)}</a>"
        else
          all
        end
      end
    end

    def auto_link_with_entities(string, entities, entity_options = {})
      options = apply_default_options(entity_options)
      text = string.to_char_a
      extra_html = HTML_ATTR_NO_FOLLOW unless options[:suppress_no_follow]

      all_entities = [];

      entities.each do |key, entities|
        all_entities.concat(entities.map{|ea| {:key => key, :entity => ea}})
      end

      all_entities.sort! do |a,b|
        a[:entity]['indices'][0] <=> b[:entity]['indices'][0]
      end

      linkers_for = {
        :urls => proc do |txt, url|
          display_url = html_escape(url['display_url'] || url['url'])
          expanded_url = html_escape(url['expanded_url'] || url['url'])
          src_url = html_escape(url['url'])
          %Q'<a href="#{src_url}" target="_blank"#{extra_html} data-expanded-url="#{expanded_url}" class="#{options[:url_class]}">#{display_url}</a>'
        end,
        :hashtags => proc do |txt, hashtag|
          escaped = html_escape(hashtag['text'])
          %Q'<a href="#{options[:hashtag_url_base]}#{escaped}" title="##{escaped}" class="#{options[:hashtag_class]}"#{extra_html}>##{escaped}</a>'
        end,
        :user_mentions => proc do |txt, user_mention|
          screen_name = html_escape(user_mention['screen_name'])
          %Q'<a class="#{options[:username_class]}" data-screen-name="#{screen_name}" href="http://twitter.com/#{screen_name}"#{extra_html}>#{screen_name}</a>'
        end
      }
      linkers_for.merge!(options[:linkers] || {})

      result = ""
      index = 0
      all_entities.each do |object|
        entity = object[:entity]
        start_index = entity['indices'][0]
        end_index = entity['indices'][1]
        result << text[index...start_index].join("")
        linker = linkers_for[object[:key].to_sym] || proc{|txt, entity| txt}
        argument = text[start_index...end_index].join("")
        result << linker.call(argument, entity)
        index = end_index
      end
      result << text[index..text.length].join("")
      result
    end

    private

    def apply_default_options(hash = {})
      options = hash.dup;
      options[:url_class] = options[:url_class] || DEFAULT_URL_CLASS;
      options[:list_class] = options[:list_class] || DEFAULT_LIST_CLASS;
      options[:username_class] = options[:username_class] || DEFAULT_USERNAME_CLASS;
      options[:username_url_base] = options[:username_url_base] || "http://twitter.com/";
      options[:list_url_base] = options[:list_url_base] || "http://twitter.com/";
      options[:hashtag_class] = options[:hashtag_class] || DEFAULT_HASHTAG_CLASS;
      options[:hashtag_url_base] = options[:hashtag_url_base] || "http://twitter.com/search?q=%23";
      options
    end

    def target_tag(options)
      target_option = options[:target]
      if target_option.blank?
        ""
      else
        "target=\"#{html_escape(target_option)}\""
      end
    end

  end
end
