module I18nDb
  module ActionController
  
    private

    def set_locale(locale='en-US')
    
      I18n.locale = locale
      I18n.populate do
        I18n.store_translations(I18n.locale, I18n.translations_from_db)
      end
      
      unless I18n::Backend::Simple.respond_to? :translate_without_default_passed_to_exception
        I18n::Backend::Simple.module_eval do
          class << self
            alias_method_chain :translate, :default_passed_to_exception            
            alias_method_chain :default, :correct_nil_for_array
          end
        end
      end
    end
  end
end