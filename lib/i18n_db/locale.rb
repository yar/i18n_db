class Locale < ActiveRecord::Base
  has_many :translations
  set_table_name "i18n_db_locales"
  validates_presence_of :iso
  validates_presence_of :short
  
  def completeness
    return 1.0 if main?
    
    main_translations_count = Locale.find_by_main(true).translations.count
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
        
  # sets up a hash with keys like "app.pages.membership/n_months_free" and values being
  # translation activerecord objects
  def self.find_main_translations
    find_by_main(true).translations.inject({}) { |memo, tr| memo["#{tr.namespace}/#{tr.tr_key}"] = tr; memo }
  end
end