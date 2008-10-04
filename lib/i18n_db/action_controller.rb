module I18nDb
  module ActionController
  
    private

    def set_locale(locale='en-US')
    
      I18n.locale = locale
      
      unless I18n.backend.send(:translations)[locale]
        I18n.backend.store_translations(I18n.locale, I18n.translations_from_db)
      end
      
      unless I18n::Backend::Simple.instance_methods.include? "translate_without_default_passed_to_exception"
        I18n::Backend::Simple.class_eval do
          alias_method_chain :translate, :default_passed_to_exception
        end
      end
    end
  end
end