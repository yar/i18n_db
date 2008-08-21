module I18nDb
  module DbLoader

    attr_accessor :record_missing_keys

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
        Locale.find_by_iso(locale).translations.find(:all).each do |tr|
          pos = translations
          unless tr.namespace.blank?
            tr.namespace.split(".").each do |ns|
              pos[ns.to_sym] ||= {}
              pos = pos[ns.to_sym]
            end
          end
          pos[tr.tr_key] = tr.text
        end
        translations
      end
    end

    def default_caching_options
      ::ActionController::Base.perform_caching ? {} : { :force => true }
    end

    def write_missing(exception, locale, key, options)
      if record_missing_keys
        if I18n::MissingTranslationData === exception
          # The scope can be either dot-delimited string or nil
          scope = options[:scope]
          scope = scope.join(".") if Array === scope
          Locale.find_by_iso(locale).translations.find_or_create_by_tr_key_and_namespace(key.to_s, scope)
                    
          # Also append the new record to the in-memory hash, to save subsequent sql requests
          store_translations(locale, hashify_scope_and_key(scope, key))
        end
      end
      default_exception_handler(exception, locale, key, options)
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
