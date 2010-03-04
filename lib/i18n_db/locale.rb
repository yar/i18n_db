class Locale < ActiveRecord::Base
  has_many :translations
  set_table_name "i18n_db_locales"
  validates_presence_of :iso
  validates_presence_of :short
  
  # Returns a floating point number between 0.0 and 1.0, reflecting the fraction of the translations that
  # are up to date in this locale (i.e. that exist and are not older than the corresponding string for 
  # the main locale 
  def completeness
    return 1.0 if main?
    
    main_translations_count = Locale.find_main_cached.translations.count
    main_translations = Locale.find_main_translations
    local_translations = translations.inject({}) { |memo, tr| memo["#{tr.namespace}/#{tr.tr_key}"] = tr; memo }
    
    outdated = 0
    main_translations.each do |key, main_tr|
      if !local_translations[key] || (local_translations[key].updated_at && main_tr.updated_at && local_translations[key].updated_at < main_tr.updated_at)
        outdated += 1
      end
    end
    (main_translations_count - outdated).to_f / main_translations_count
  end
  
  class << self
    extend ActiveSupport::Memoizable
    
    def find_main_cached
      find_by_main(1)
    end
    memoize :find_main_cached

    # Sets up a hash with keys like "app.pages.membership/n_months_free" and values being
    # translation activerecord objects
    def find_main_translations
      find_main_cached.translations.inject({}) { |memo, tr| memo["#{tr.namespace}/#{tr.tr_key}"] = tr; memo }
    end
  end        
end