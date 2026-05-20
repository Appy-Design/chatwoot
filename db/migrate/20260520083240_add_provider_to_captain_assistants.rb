class AddProviderToCaptainAssistants < ActiveRecord::Migration[7.1]
  def change
    add_column :captain_assistants, :provider, :string, null: true
    add_column :captain_assistants, :model_override, :string, null: true
    add_index :captain_assistants, :provider
  end
end
