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
  
  def name_for_tolk
    case self.short
    when "pt"
      "pt-PT"
    else
      self.short
    end
  end
  
  def migrate_to_tolk
    tolk_locale = Tolk::Locale.find_or_create_by_name(self.name_for_tolk, :updated_at => self.updated_at)
    
    tolk_phrases = Tolk::Phrase.find(:all, :order => "`key`").inject({}) { |acc, el| acc[el.key] = el; acc }
    tolk_translations = tolk_locale.translations.find(:all, :order => "phrase_id").inject({}) { |acc, el| acc[el.phrase_id] = el; acc }

    self.translations.non_blank.find(:all, :order => "id").each do |tr|
      if tolk_phrase = tolk_phrases[tr.tolk_key]
        if tolk_translation = tolk_translations[tolk_phrase.id]
          unless tolk_translation.text == tr.text 
            logger.debug "TOLK MIGR.: translation #{tr.id} duplicates another"
          end
        else
          begin
            new_tolk_translation = tolk_locale.translations.build :phrase => tolk_phrase,
              :text => tr.text,
              :created_at => tr.created_at,
              :updated_at => tr.updated_at
            def new_tolk_translation.check_matching_variables
              # check nothing
            end
            new_tolk_translation.save!
            tolk_translations[tolk_phrase.id] = new_tolk_translation
          rescue ActiveRecord::RecordInvalid
            logger.debug "TOLK MIGR.: skipping translation #{tr.id} (#{self.short}) of #{tr.counterpart_in_main.id} (main) which failed validation"
          end
        end
      else
        logger.debug "TOLK MIGR.: cannot find Tolk phrase for translation #{tr.id}"
      end
    end
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
    
    def migrate_all_to_tolk
      create_tolk_phrases_from_main_locale
      
      Locale.find(:all, :order => "main DESC, id").each do |locale|
        locale.migrate_to_tolk
      end
    end
    
    def create_tolk_phrases_from_main_locale
      tolk_phrases = Tolk::Phrase.find(:all, :order => "`key`").inject({}) { |acc, el| acc[el.key] = el; acc }             
      # the main locale is populated first, so that Tolk macro validations will work in all others
      find_main_cached.translations.non_blank.find(:all, :order => "id").each do |tr|
        unless tolk_phrases[tr.tolk_key]
          tolk_phrases[tr.tolk_key] = Tolk::Phrase.create! :key => tr.tolk_key,
            :created_at => tr.created_at,
            :updated_at => tr.updated_at
        end
      end
      
    end
  end        
end