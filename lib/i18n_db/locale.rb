class Locale < ActiveRecord::Base
  has_many :translations
  set_table_name "i18n_db_locales"
  validates_presence_of :iso
  validates_presence_of :short
  
  def self.find_main_cached
    @@main_cached ||= find_by_main(1)
  end
end