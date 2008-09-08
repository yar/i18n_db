class Locale < ActiveRecord::Base
  has_many :translations
  set_table_name "i18n_db_locales"
  validates_presence_of :iso
  validates_presence_of :short
end