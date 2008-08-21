Dir.glob(File.join(File.dirname(__FILE__), 'lib', 'i18n_db', '*.rb')).each{|f| require f}
ActionController::Base.send :include, I18nDb::ActionController
I18n.extend I18nDb::DbLoader
I18n.exception_handler = :write_missing

