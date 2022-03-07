# require 'sinatra'
require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/namespace'
require 'mongoid'

Mongoid.load! "mongoid.config"

class Book
  include Mongoid::Document
  
  field :title, type: String
  field :author, type: String
  field :isbn, type: String

  validates :title, presence: true
  validates :author, presence: true
  validates :isbn, presence: true

  index({ title: 'text' })
  index({ isbn:1 }, { unique: true, name: "isbn_index" })

  scope :title, -> (title) { where(title: /^#{title}/) }
  scope :isbn, -> (isbn) { where(isbn: isbn) }
  scope :author, -> (author) { where(author: author) }
end

# Serializers
class BookSerializer
  def initialize(book)
    @book = book
  end

  def as_json(*)
    data = {
      id:@book.id.to_s,
      title:@book.title,
      author:@book.author,
      isbn:@book.isbn
    }
    data[:errors] = @book.errors if @book.errors.any?
    data
  end
end


class App < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
    after_reload do
      puts 'reloaded'
    end
  end

  register Sinatra::Namespace

  get '/' do
    'Welcome to BookList!'
  end

  namespace '/api/v1' do
    before do
      content_type :json
    end
  
    get '/books' do
      books = Book.all

      [:title, :isbn, :author].each do |filter|
        books = books.send(filter, params[filter]) if params[filter]
      end

      books.map { |book| BookSerializer.new(book) }.to_json
    end

    get '/books/:id' do |id|
      book = Book.where(id: id).first
      halt(404, { message:'Book Not Found'}.to_json) unless book
      BookSerializer.new(book).to_json
    end
  end

  run! if app_file == $0
end
