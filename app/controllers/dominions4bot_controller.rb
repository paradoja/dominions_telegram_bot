# coding: utf-8
class Dominions4botController < Telegram::Bot::UpdatesController
  rescue_from Exception, :with => :log_error
  PORTS = (1024..1029).to_a
  include Telegram::Bot::UpdatesController::MessageContext
  include StatsUtils
  include GamesUtils
  require 'byebug'

  before_action :connect_db
  before_action :set_username
  before_action :set_player

  NUMERICAL_KEYBOARD = [
    ["1", "2", "3"],
    ["4", "5", "6"],
    ["7", "8", "9"],
    ["0"]
  ]
  NATIONS = {"Rag" => "Ragha", "Jom" => "Jomon", "Ut" => "Utgard", "Bog" => "Bogarus", "Rl" => "R'lyeh", "Lem" => "Lemuria", "Rap" => "Caelum", "DT" => "C'Tis", "BK" => "T'ien Ch'i"    }

  PORTS.each do |i|
    define_method("im_playing_in_#{i}!") do
      respond_with :message, text: "¿quién eres en #{i}?", reply_markup: {inline_keyboard:  im_playing_in(i)}
    end

    define_method("status_#{i}!") do
      respond_with :message, text: "Status #{i}:\n #{status(i)}", parse_mode: :Markdown
    end
  end


  def callback_query(data)
    order = data.split
    send order[0], order[1]
  end

  def soy!(player_game)
    arr = player_game.split "@"
    nation = arr.first
    port = arr.last
    game = Game.find_by port: port
    pg = PlayerGame.find_or_create_by player: @player, game: game
    pg.nation =  nation
    pg.save!
    respond_with :message, text: "Hola #{@username} eres #{nation} en #{port} "
  end



  #tells the player in which games she/he has pending turns
  def need_drugs!
    pgs = PlayerGame.where player: @player

    drugs = pgs.map { |p| ["#{p.gm_port}: #{find_nation_status(p.gm_port,p.nation)}"] }.flatten.join "\n"

    respond_with :message, text: "Hola #{@username}, tus dronjas:\n#{drugs}"
  end

  def im_playing_in(port)
    players = playing_nations port

    answers = players.map do |player|
      [{text: "Soy #{player[0...-1]}", callback_data: "soy! #{player[0...-1]}@#{port}"}]
    end

    respond_with :message, text: "¿quién eres en #{port}?", reply_markup: {inline_keyboard:  answers}
  end

  #new
  def status(port)
    game_status = ''
    lines = File.readlines("/tmp/#{port}.log", chomp: true).last(2)
    game_status << lines.first
    lines[1].scan(/([A-Za-z]{1,2}[a-z]{0,2}[-?*+])/).each do |nation_line|
      nation = nation_line.last[0...-1]

      pgs = PlayerGame.joins(:game).where nation: nation, "games.port" => port
      nation_status =  player_status(nation_line.last.last.last)
      if (!pgs.empty? && nation_status != "Jugado")
        nation += " @#{pgs.first.player.username}"
      end
      game_status << "\n *#{nation_name(nation)}:* #{nation_status}"
    end
    game_status
  rescue => e
    Logger.new(STDOUT).error "Ups! Doing status #{port} got: #{e.message}"
  end



  def action_missing(action, *_args)
    respond_with :message, text: "Eso no se que es"
  end

  def scores_1028!
    respond_with :message, text: read_scores_file_1028, parse_mode: "html"
  end

  private

  def find_nation_status(port, nation)
    nations = playing_nations port
    idx = nations.index {|current| current.start_with? nation}
    player_status(nations[idx][-1])
  end

  def playing_nations port
    lines = File.readlines("/tmp/#{port}.log", chomp: true).last(2)
    lines[1].scan(/([A-Z]{1,2}[a-z]{0,}[-?*+])/).map {|player| player.last }
  end

  def connect_db
    unless ActiveRecord::Base.connected?
      ActiveRecord::Base.establish_connection(adapter:  'sqlite3', database: 'db/development.sqlite3')
    end
  end

  def player_status(status)
   case(status)
   when "+"
     "Jugado"
   when "?"
     "A medias"
   when "-"
     "Pendiente"
   when "*"
     "*Conectado*"
   else
     status
   end
  end

  def nation_name(acron)
   NATIONS[acron] || acron
  end

  def connect_db
   unless ActiveRecord::Base.connected?
     ActiveRecord::Base.establish_connection(adapter:  'sqlite3', database: 'db/development.sqlite3')
   end
  end

  def set_msg
   @msg =  update["message"]["from"]["text"] || update["message"]["text"]
   if (@msg =~ /[ ]/).nil? then
     @msg = nil
   else
     @msg = @msg[((@msg =~ /[ ]/) + 1)..@msg.length]
   end
  end

  def is_number? string
   true if Float(string) rescue false
  end

  def set_username
    @username =  update["message"]["from"]["username"]
  rescue
    @username = update["callback_query"]['from']['username']
  end

  def set_player
    @player = Player.find_or_create_by username: @username
  end

  def log_error(e)
    Logger.new(STDOUT).error "\n********************\nUps! Exception raised, got: #{e.message}\n********************\n"
    respond_with :message, text: "Ups!\n\n```#{e.message}```\nNada que ver, circulen...", parse_mode: :Markdown
  end

end
