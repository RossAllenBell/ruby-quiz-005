require 'io/console'
require 'pry'

def main
  game = parse_level(file_path: ARGV[0])

  puts "Game file parsed"

  input = nil
  game.print_state
  while !game.over? && input.to_s.downcase != 'x'
    game.print_instructions
    input = get_input
    game.process_input(input: input)
    game.print_state

    if game.over?
      puts "Complete!"
    end
  end

  puts "Game ending"
end

def parse_level(file_path:)
  file_contents = File.read(file_path)
  tile_chars = []
  file_contents.split(/\n/).each do |line|
    if line.to_s.size > 0
      row = []
      line.split('').each do |tile_char|
        row << tile_char
      end
      tile_chars << row
    end
  end

  return Game.new(
    board: Board.new(
      tile_chars: tile_chars,
    ),
  )
end

def get_input
  STDIN.echo = false
  STDIN.raw!

  input = STDIN.getc.chr
  if input == "\e" then
    input << STDIN.read_nonblock(3) rescue nil
    input << STDIN.read_nonblock(2) rescue nil
  end
ensure
  STDIN.echo = true
  STDIN.cooked!

  return input
end

class Board

  module Tiles
    Wall = '#'
    Man = '@'
    Crate = 'o'
    Floor = ' '
    Storage = '.'
    CrateOnStorage = '*'
    ManOnStorage = '+'
    All = Tiles.constants(false).map { |c| Tiles.const_get c }
  end

  attr_accessor :tiles

  def initialize(tile_chars:)
    self.tiles = tile_chars.dup

    self.validate_tiles!
  end

  def validate_tiles!
    fail('must be at least three rows tall') unless self.tiles.size >= 3

    columns_count = nil
    self.tiles.each do |row|
      columns_count ||= row.size
      fail('must be at least three columns tall') unless row.size >= 3
      # fail('inconsistent column counts') unless columns_count == row.size

      # fail('missing wall at beginning of row') unless row.first == Tiles::Wall
      # fail('missing wall at end of row') unless row.last == Tiles::Wall
    end

    # fail('not all walls on top row') unless self.tiles.first.all?{|t| t == Tiles::Wall}
    # fail('not all walls on bottom row') unless self.tiles.last.all?{|t| t == Tiles::Wall}
  end

  def complete?
    return tiles.flatten.none?{|t| t == Tiles::Crate}
  end

  def can_move?(direction:)
    origin_space_coord = player_coord
    destination_space_coord = origin_space_coord + direction
    beyond_destination_space_coord = destination_space_coord + direction

    origin_space = self.tiles[origin_space_coord.y][origin_space_coord.x]
    destination_space = self.tiles[destination_space_coord.y][destination_space_coord.x]

    if [Tiles::Wall].include?(destination_space)
      return false
    elsif [Tiles::Crate, Tiles::CrateOnStorage].include?(destination_space)
      beyond_destination_space = self.tiles[beyond_destination_space_coord.y][beyond_destination_space_coord.x]
      if [Tiles::Wall, Tiles::Crate, Tiles::CrateOnStorage].include?(beyond_destination_space)
        return false
      end
    end

    return true
  end

  def move(direction:)
    origin_space_coord = player_coord
    destination_space_coord = origin_space_coord + direction
    beyond_destination_space_coord = destination_space_coord + direction

    origin_space_before = self.tiles[origin_space_coord.y][origin_space_coord.x]
    destination_space_before = self.tiles[destination_space_coord.y][destination_space_coord.x]
    beyond_destination_space_before = self.tiles[beyond_destination_space_coord.y][beyond_destination_space_coord.x]

    origin_space_after = if [Tiles::ManOnStorage].include?(origin_space_before)
      Tiles::Storage
    else
      Tiles::Floor
    end

    destination_space_after = if [Tiles::CrateOnStorage, Tiles::Storage].include?(destination_space_before)
      Tiles::ManOnStorage
    else
      Tiles::Man
    end

    beyond_destination_space_after = beyond_destination_space_before
    if [Tiles::Crate, Tiles::CrateOnStorage].include?(destination_space_before)
      beyond_destination_space_after = if [Tiles::Storage].include?(beyond_destination_space_before)
        Tiles::CrateOnStorage
      else
        Tiles::Crate
      end
    end

    self.tiles[origin_space_coord.y][origin_space_coord.x] = origin_space_after
    self.tiles[destination_space_coord.y][destination_space_coord.x] = destination_space_after
    self.tiles[beyond_destination_space_coord.y][beyond_destination_space_coord.x] = beyond_destination_space_after
  end

  def player_coord
    x = self.tiles.detect{|row| ([Tiles::Man, Tiles::ManOnStorage] & row).size > 0}.index{|tile| [Tiles::Man, Tiles::ManOnStorage].include?(tile)}
    y = self.tiles.index{|row| ([Tiles::Man, Tiles::ManOnStorage] & row).size > 0}

    return Coord.new(
      x: x,
      y: y,
    )
  end

end

class Game

  attr_accessor :board

  def initialize(board:)
    self.board = board
  end

  def over?
    return board.complete?
  end

  def print_state
    puts ''
    self.board.tiles.each do |row|
      puts row.join('')
    end
    puts ''
  end

  def print_instructions
    puts "Move (x to quit):"
  end

  def process_input(input:)
    case input
    when "\e[A" # UP ARROW
      try_move_up
    when "\e[B" # DOWN ARROW
      try_move_down
    when "\e[C" # RIGHT ARROW
      try_move_right
    when "\e[D" # LEFT ARROW
      try_move_left
    when "\u0003"
      exit
    else
      puts "Unknown input: #{input.inspect}"
    end
  end

  def try_move_up
    try_move(direction: Coord.new(x: 0, y: -1))
  end

  def try_move_down
    try_move(direction: Coord.new(x: 0, y: 1))
  end

  def try_move_right
    try_move(direction: Coord.new(x: 1, y: 0))
  end

  def try_move_left
    try_move(direction: Coord.new(x: -1, y: 0))
  end

  def try_move(direction:)
    if self.board.can_move?(direction: direction)
      self.board.move(direction: direction)
    end
  end

end

class Coord

  attr_accessor :x, :y

  def initialize(x:, y:)
    self.x = x
    self.y = y
  end

  def +(other)
    Coord.new(
      x: self.x + other.x,
      y: self.y + other.y,
    )
  end

end

main
