module I18n
  module Backend
    module Simple
      class << self
        # This one is needed because translate normally discards the default value from 
        # the information passed to MissingTranslationData handler, preventing it 
        # from trying a fallback locale correctly
        def translate_with_default_passed_to_exception(locale, key, options = {})
          if options[:default]
            options[:saved_default] = options[:default]
          end
          translate_without_default_passed_to_exception(locale, key, options)
        end

        # This method is fixed to correctly return nil for an array where none of the keys
        # has a translation - also crucial for fallback locales
        def default_with_correct_nil_for_array(locale, default_val, options = {})
          if Array === default_val
            default_val.each do |obj|
              result = default_without_correct_nil_for_array(locale, obj, options.dup) and return result
            end
            return nil
          else
            return default_without_correct_nil_for_array(locale, default_val, options)
          end
        end
      end
    end
  end
end