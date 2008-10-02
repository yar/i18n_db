class Translation < ActiveRecord::Base
  belongs_to :locale
  set_table_name "i18n_db_translations"
  
  def validate
    unless locale.main?
      main_tr = counterpart_in_main
      if main_tr
        if main_tr.count_macros != count_macros
          errors.add("text", "did not preserve macro variables, e.g. {{to_be_kept}}. Please do not change or translate the macros.")
        end
        if main_tr.count_link_targets != count_link_targets
          errors.add("text", "did not preserve html links, e.g. <a href=\"to_be_kept\">...</a>. Please do not change or translate the URLs.")
        end
      end
    end
  end
  
  def count_macros
    macros = {}
    text.scan /\{\{(.*?)\}\}/ do |matches|
      key = matches.first
      macros[key] ||= 0
      macros[key] += 1
    end
    macros
  end
  
  def count_link_targets
    link_targets = {}
    text.scan /href=(.*?)>/ do |matches|
      key = matches.first
      link_targets[key] ||= 0
      link_targets[key] += 1
    end
    link_targets
  end


  def counterpart_in(locale)
    locale.translations.find(:first, :conditions => { :namespace => namespace, :tr_key => tr_key }) \
    || locale.translations.build(:namespace => namespace, :tr_key => tr_key)
  end
  
  def counterpart_in_main
    Locale.find_main_cached.translations.find(:first, :conditions => { :namespace => namespace, :tr_key => tr_key })
  end

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
