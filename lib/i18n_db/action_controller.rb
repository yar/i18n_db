module I18nDb
  module ActionController
  
    private

    def set_locale(locale='en-US')
    
      I18n.locale = locale
      I18n.backend.store_translations(I18n.locale, I18n.translations_from_db)
      
      unless I18n::Backend::Simple.instance_methods.include? "translate_without_default_passed_to_exception"
        I18n::Backend::Simple.class_eval do
          alias_method_chain :translate, :default_passed_to_exception
          alias_method_chain :default, :correct_nil_for_array
        end
      end
    end
  end
end