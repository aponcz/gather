# Company-switch codes grant a session and must not appear in request logs.
Rails.application.config.filter_parameters += [:code]
