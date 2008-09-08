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
  
  def self.simple_localization_to_sql(locale, path)
    hash = YAML.load_file(path)
    hash_to_sql(locale, hash["app"], "app")
  end
  
  def self.hash_to_sql(locale, hash, namespace)
    hash.each do |key, val|
      if Hash === val
        hash_to_sql(locale, val, "#{namespace}.#{key}")
      else
        locale.translations.create \
          :tr_key => key, 
          :namespace => namespace, 
          :text => simple_localization_escaping_to_rails(val)
      end
    end
  end
  
  def self.simple_localization_escaping_to_rails(str)
    str.gsub(/:(\w[\w\d_]*)/, '{{\\1}}')
  end

end
