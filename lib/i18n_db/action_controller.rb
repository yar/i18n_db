module I18nDb
  module ActionController
  
    private

    def set_locale(locale='en-US')
    
      I18n.locale = locale
      I18n.populate do
        I18n.store_translations(I18n.locale, I18n.translations_from_db)
      end
    end
  end
end