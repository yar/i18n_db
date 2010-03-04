module I18nDb
  module DbLoader

    attr_accessor :record_missing_keys
    
    def translations_from_db(locale = I18n.locale.to_s)
      translations = {}
      if locale_obj = Locale.find_by_short(locale)
        locale_obj.translations.find(:all).each do |tr|
          pos = translations
          unless tr.namespace.blank?
            tr.namespace.split(".").each do |ns|
              pos[ns.to_sym] ||= {}
              pos = pos[ns.to_sym]
            end
          end
          # begin
            pos[tr.tr_key.to_sym] = tr.text unless tr.tr_key.blank?
          # rescue ArgumentError
          #   # logger.warn "ArgumentError, tr_key: #{tr.tr_key}, translation: #{tr.inspect}"
          # end
        end
      end
      translations
    end

    def default_caching_options
      ::ActionController::Base.perform_caching ? {} : { :force => true }
    end
    
    def write_missing_and_try_default_locale(exception, locale, key, options={})
      write_missing(exception, locale, key, options)
      main_locale = Locale.find_main_cached
      if !main_locale || (locale == Locale.find_main_cached.short) # main locale can be missing, say, in tests
        default_exception_handler(exception, locale, key, options)
      else
        default = options.delete(:saved_default)
        return translate(key, options.merge(:locale => Locale.find_main_cached.short, :default => default))
      end
    end

    def write_missing(exception, locale, key, options)
      if record_missing_keys
        if I18n::MissingTranslationData === exception
          # Not saving anything unless there are locales defined
          if main_locale = Locale.find_main_cached

          # The scope can be either dot-delimited string or nil
          scope = options[:scope]
          scope = scope.join(".") if Array === scope
          
          if scope
            full_str_key = "#{scope}->#{key}"
          else
            full_str_key = "#{key}"
          end

            # We cache the already detected misses to avoid SQL requests
            unless Rails.cache.exist?("locales_missing/#{locale}/#{full_str_key}")
              if locale.to_s == main_locale.short
                locale_obj = main_locale
              else
                locale_obj = Locale.find_by_short(locale.to_s)
              end
              if locale_obj && key.to_s != ""
                # We should not create "bar" in "foo" if "foo.bar" namespace exists
                unless locale_obj.translations.count(:conditions => { :namespace => "#{scope}.#{key}"}) > 0
                  # The opposite also applies:
                  # we should not create "foo.bar.qux.baz" 
                  # if key "bar" exists in "foo" 
                  # or key "qux" exists in "foo.bar" 
                  # or key "baz" etc...
                  used_parts = []
                  conflicting_record = nil
                  scope.split(".").each do |part|
                    break if conflicting_record = locale_obj.translations.find_by_namespace_and_tr_key(used_parts.join("."), part)
                    used_parts << part
                  end
                  unless conflicting_record
                    locale_obj.translations.find_or_create_by_tr_key_and_namespace(key.to_s, scope)
                  end
                end
              end
              Rails.cache.write("locales_missing/#{locale}/#{full_str_key}", true)
            end
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
