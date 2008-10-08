module I18nDb
  module DbLoader

    attr_accessor :record_missing_keys
    
    DEFAULT_RAILS_LOCALE = 'en-US'

    # Loads all translations for a certain locale.
    # 
    # The options are passed to caching options.
    # It only caches if you specified config.action_controller.perform_caching = true in your environment.
    #   
    #   I18n.translations_from_db('nl-NL')                         # Use Rails' caching settings
    #   I18n.translations_from_db('nl-NL', :force => true)         # Don't use caching, ignoring Rails' settings
    #   I18n.translations_from_db('nl-NL', :force => false)        # Always use caching, ignoring Rails' settings
    #   I18n.translations_from_db('nl-NL', :expiry => 1.day.to_i)  # Alternative caching options if your cache_store supports it
    #
    def translations_from_db(locale = I18n.locale, options = {})
      caching_options = default_caching_options.merge(options)
      Rails.cache.fetch("locales/#{locale}", caching_options) do
        translations = {}
        if locale_obj = Locale.find_by_iso(locale)
          locale_obj.translations.find(:all).each do |tr|
            pos = translations
            unless tr.namespace.blank?
              tr.namespace.split(".").each do |ns|
                pos[ns.to_sym] ||= {}
                pos = pos[ns.to_sym]
              end
            end
            pos[tr.tr_key] = tr.text
          end
        end
        translations
      end
    end

    def default_caching_options
      ::ActionController::Base.perform_caching ? {} : { :force => true }
    end
    
    def write_missing_and_try_default_locale(exception, locale, key, options={})
      write_missing(exception, locale, key, options)
      if locale == DEFAULT_RAILS_LOCALE
        default_exception_handler(exception, locale, key, options)
      else
        default = options.delete(:saved_default)
        return translate(key, options.merge(:locale => DEFAULT_RAILS_LOCALE, :default => default))
      end
    end

    def write_missing(exception, locale, key, options)
      if record_missing_keys
        if I18n::MissingTranslationData === exception
          # The scope can be either dot-delimited string or nil
          scope = options[:scope]
          scope = scope.join(".") if Array === scope
          
          if scope
            full_str_key = "#{scope}.#{key}"
          else
            full_str_key = "#{key}"
          end

          # We cache the already detected misses to avoid SQL requests
          unless Rails.cache.exist?("locales_missing/#{locale}/#{full_str_key}")
            if locale_obj = Locale.find_by_iso(locale)
              locale_obj.translations.find_or_create_by_tr_key_and_namespace(key.to_s, scope)
            end
            Rails.cache.write("locales_missing/#{locale}/#{full_str_key}", nil)
          end
        end
      end
    end
    
    # "one.two.three", "foo" => {:one => {:two => {:three => {:foo => nil }}}}
    def hashify_scope_and_key(scope_str, key)
      new_chunk = {}
      cur = "#{scope_str}".split(".").map { |str| str.to_sym }.inject(new_chunk) { |mem, var| mem[var] = {} }
      cur[key.to_sym] = nil
      new_chunk
    end
  end
end
