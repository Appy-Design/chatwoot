module AppyInstallationHelper
  def appy_installation?
    ENV['APPY_INSTALLATION'].to_s == 'true'
  end
  module_function :appy_installation?
end
