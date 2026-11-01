# Health reasons were stored as French sentences ({ "text" }); they are now
# translation keys with their parameters ({ "key", "params" }), written in
# the reader's language. Computes them again from the inventory already
# stored (no SSH): the state does not change, only how reasons are stored.
class RefreshHealthReasons < ActiveRecord::Migration[8.1]
  def up
    Server.reset_column_information
    say_with_time "health reasons of #{Server.count} servers" do
      Server.find_each do |server|
        server.refresh_health!
      rescue StandardError => e
        say "#{server.name}: #{e.class}", true
      end
    end
  end

  def down
    # Nothing to undo: older versions read the new reasons as unknown.
  end
end
