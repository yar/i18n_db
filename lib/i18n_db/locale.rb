class Locale < ActiveRecord::Base
  has_many :translations
  set_table_name "i18n_db_locales"
  
end