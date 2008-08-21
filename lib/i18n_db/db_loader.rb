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
    Rails.cache.fetch("locales/#{select_locale(locale)}", caching_options) do
      translations = {}
      Locale.find_by_iso(locale).translations.find(:all).each do |tr|
        pos = translations
        tr.namespace.split(".").each do |ns|
          pos[ns.to_sym] ||= {}
          pos = pos[ns.to_sym]
        end
        pos[tr.tr_key] = tr.text
      end
      translations
    end
  end

  def default_caching_options
    ::ActionController::Base.perform_caching ? {} : { :force => true }
  end
end
