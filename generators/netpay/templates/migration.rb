class CreateNetpayLogs < ActiveRecord::Migration
  def self.up
    create_table :netpay_logs, :force => true do |t|
      t.string    :request, :limit => 1024
      t.string    :response, :limit => 1024
      t.string    :exception
      t.string    :netpay_status, :limit => 3
      t.integer   :http_code
      t.timestamps
    end

  end
  
  def self.down
    drop_table :netpay_logs
  end
end