class Translation < ActiveRecord::Base
  belongs_to :locale
  set_table_name "i18n_db_translations"

  def self.pick(key, locale, namespace = nil)
    conditions = 'tr_key = ? AND locale_id = ?'
    namespace_condition = namespace ? ' AND namespace = ?' : ' AND namespace IS NULL'
    conditions << namespace_condition
    find(:first, :conditions => [conditions,*[key, locale.id, namespace].compact])
  end

  #Find all namespaces used in translations
  def self.find_all_namespaces
    sql = <<-SQL
SELECT distinct(namespace) FROM i18n_db_translations order by namespace
SQL
    self.connection.select_values(sql).compact
  end

end
