module I18n
  module Backend
    class Simple
      # This one is needed because translate normally discards the default value from 
      # the information passed to MissingTranslationData handler, preventing it 
      # from trying a fallback locale correctly
      def translate_with_default_passed_to_exception(locale, key, options = {})
        if options[:default]
          options[:saved_default] = options[:default]
        end
        translate_without_default_passed_to_exception(locale, key, options)
      end
    end
  end
end