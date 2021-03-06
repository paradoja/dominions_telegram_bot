class Game < ActiveRecord::Base
  #TODO enum for eras
  validates_presence_of :name
  validates_presence_of :era
  validates :port, numericality: { greater_than: 0, less_than: 25000 }
  has_many :player_games, dependent: :destroy

  def to_s
    "#{name}\n
     - current_turn: #{current_turn}\n
     - era: #{era}\n
     - created_at: #{created_at}\n
     - updated_at: #{updated_at}\n
     - port: #{port}\n"
  end
end



