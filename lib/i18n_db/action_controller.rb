module I18nDb
  module ActionController
  
    private
    
    def reload_translations_for_locale(locale, updated_at)
      translations = Rails.cache.fetch("locales/#{locale}/#{updated_at.to_i}") do
        I18n.translations_from_db(locale)
      end
      
      I18n.backend.instance_eval do
        # wipe the existing app-level translations from memory, because 
        # otherwise stale items could remain after the merge
        if @translations && @translations[locale.to_sym] && @translations[locale.to_sym][:app]
          @translations[locale.to_sym][:app] = {} 
        end
      end
      
      I18n.backend.store_translations(I18n.locale, translations)
      nil
    end
    
    def ensure_translations_updated(locale)
      loc_obj = nil
      
      updated_at = Rails.cache.fetch("locale_versions/#{locale}") do
        loc_obj = Locale.find_by_iso(locale)
        loc_obj.updated_at if loc_obj
      end
      
      return false unless updated_at || loc_obj
      
      cached_versions = I18n.backend.instance_eval { @locale_versions }
      unless cached_versions 
        cached_versions = {}
      end
      unless cached_versions[locale] && cached_versions[locale] == updated_at
        reload_translations_for_locale(locale, updated_at)
        cached_versions[locale] = updated_at
      end
      I18n.backend.instance_eval { @locale_versions = cached_versions }
    end

    def set_locale(locale='en-US')
      I18n.locale = locale.to_sym
      
      ensure_translations_updated(locale)
                  
      unless I18n::Backend::Simple.instance_methods.include? "translate_without_default_passed_to_exception"
        I18n::Backend::Simple.class_eval do
          alias_method_chain :translate, :default_passed_to_exception
        end
      end
    end
  end
end