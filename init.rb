require "lib/i18n_db/action_controller"
require "lib/i18n_db/db_loader"
I18n.extend I18nDb::DbLoader
ActionController::Base.send :include, I18nDb::ActionController
