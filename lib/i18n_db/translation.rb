class Translation < ActiveRecord::Base
  belongs_to :locale
  set_table_name "i18n_db_translations"
  named_scope :non_blank, :conditions => "text IS NOT NULL AND text <> ''"
  
  def validate
    unless locale.main?
      main_tr = counterpart_in_main
      if main_tr && !main_tr.text.blank?
        if main_tr.count_macros != count_macros
          errors.add("text", "did not preserve macro variables, e.g. %{to_be_kept}. Please do not change or translate the macros.")
        end
        if main_tr.count_link_targets != count_link_targets
          errors.add("text", "did not preserve html links, e.g. <a href=\"to_be_kept\">...</a>. Please do not change or translate the URLs.")
        end
      end
    end
  end
  
  def syntax_matches?(counterpart)
    if counterpart && !counterpart.text.blank?
      if counterpart.count_macros != count_macros
        return false
      end
      if counterpart.count_link_targets != count_link_targets
        return false
      end
      return true
    else
      return true
    end
  end
  
  def count_macros
    macros = {}
    "#{text}".scan /%\{(.*?)\}/ do |matches|
      key = matches.first
      macros[key] ||= 0
      macros[key] += 1
    end
    macros
  end
  
  def count_link_targets
    link_targets = {}
    "#{text}".scan /href=(.*?)>/ do |matches|
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
  
  # Corresponding translations will be copied to the new place in all locales where destination does not exist already
  def safe_copy_to(new_namespace, new_key)
    created_list = []
    Locale.find(:all).each do |loc|
      puts "Locale #{loc.short}"
      source = counterpart_in(loc)
      target = loc.translations.find_or_initialize_by_namespace_and_tr_key(new_namespace, new_key)
      puts "Source #{source.id}, target #{target.id}"
      
      if source && !source.text.blank? && (target.new_record? || target.text.blank?)
        target.text = source.text
        target.save(false) # macros may not correspond to the main locale version, but we are copying so we do not enforce it
        created_list << target
      end
    end
    created_list
  end
  
  def tolk_key
    # self.namespace.gsub("app.", "") + "." + self.tr_key
    self.namespace + "." + self.tr_key
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
    str.gsub(/:(\w[\w\d_]*)/, '%{\\1}')
  end
end
