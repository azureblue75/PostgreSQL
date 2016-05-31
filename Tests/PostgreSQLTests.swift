//
//  PostgreSQLTests.swift
//  PostgreSQL
//
//  Created by David Ask on 17/02/16.
//
//

import XCTest
@testable import PostgreSQL


public final class StandardOutputAppender: Appender {
    public var name: String = "Standard Output Appender"
    public var closed: Bool = false
    public var level: Log.Level = .all
    
    public init () {}
    
    public func append(_ event: LoggingEvent) {
        var logMessage = "\(event.message) \n"
        let file = event.locationInfo.file
        logMessage += "In File: \(file)"
        logMessage += "\n"
        let line = event.locationInfo.line
        logMessage += "Line: \(line)"
        logMessage += "\n"
        let function = event.locationInfo.function
        logMessage += "Called From: \(function)"
        logMessage += "\n"
        print(logMessage)
    }
}

// MARK: - Models

final class Artist {
    var id: Int?
    var name: String
    var genre: String?

    init(name: String, genre: String) {
        self.id = nil
        self.name = name
        self.genre = genre
    }
}

extension Artist: Model {
    enum Field: String {
        case id = "id"
        case name = "name"
        case genre = "genre"
    }
    
    static let tableName: String = "artists"
   	static var primaryKeyField: Field = .id

    var primaryKey: Int? {
        get {
            return id
        }
        set {
            id = newValue
        }
    }
    
    var serialize: [Field: ValueConvertible?] {
        return [.name: name, .genre: genre]
    }
    
    convenience init(row: Row) throws {
        try self.init(
            name: row.value(Artist.field(.name)),
            genre: row.value(Artist.field(.genre))
        )
        id = try row.value(Artist.field(.id))
    }
}

final class Album {
    let id: Int
    var name: String
    var artistId: Artist.PrimaryKey
    
    init(id: Int, name: String, artistId: Artist.PrimaryKey) {
        self.id = 100
        self.name = name
        self.artistId = artistId
    }
}

extension Album: Model {
    enum Field: String {
        case id = "id"
        case name = "name"
        case artistId = "artist_id"
    }
    
    static let tableName: String = "artists"
   	static let primaryKeyField: Field = .id
    
    
    var primaryKey: Int? {
        get {
            return id
        }
        set {
            return
        }
    }
    
    var serialize: [Field: ValueConvertible?] {
        return [ .name: name, .artistId: artistId ]
    }
    
    convenience init(row: Row) throws {
        try self.init(
            id: try row.value(Album.field(.id)),
            name: row.value(Album.field(.name)),
            artistId: row.value(Album.field(.artistId))
        )
        
    }    
}

// MARK: - Tests

class PostgreSQLTests: XCTestCase {
    
    let connection = try! PostgreSQL.Connection(URI("postgres://localhost:5432/swift_test"))
    

    let logger = Logger(name: "SQL Logger", appenders: [StandardOutputAppender()])

    
    override func setUp() {
        super.setUp()
        
        do {
            try connection.open()
            try connection.execute("DROP TABLE IF EXISTS albums")
            try connection.execute("DROP TABLE IF EXISTS artists")
            try connection.execute("CREATE TABLE IF NOT EXISTS artists(id SERIAL PRIMARY KEY, genre VARCHAR(50), name VARCHAR(255))")
            try connection.execute("CREATE TABLE IF NOT EXISTS albums(id SERIAL PRIMARY KEY, name VARCHAR(255), artist_id int references artists(id))")
            
            try connection.execute("INSERT INTO artists (name, genre) VALUES('Josh Rouse', 'Country')")
            
            connection.logger = logger

            
        }
        catch {
            XCTFail("Connection error: \(error)")
        }
    }
    
    func testSimpleRawQueries() throws {
        try connection.execute("SELECT * FROM artists")
        let result = try connection.execute("SELECT * FROM artists WHERE name = %@", parameters: "Josh Rouse")

        XCTAssert(try result.first?.value("name") == "Josh Rouse")
    }
    
    func testRockArtists() throws {
        

        do {
            let rockArtists = try Artist.fetch(where: Artist.field(.genre).isNull(), connection: connection)
            
            try connection.begin()
            
            for var artist in rockArtists {
                artist.genre = "Rock 'n Roll"
                try artist.save(connection: connection)
            }
            
            try connection.commit()
        }
        catch {
            print(error)
            throw error
        }
        
        
    }
    
    func testSelect() throws {
        do {
            let selectQuery = Artist.select().filter(Artist.field(.name) == "Josh Rouse").first
            Artist.insert([.name: "AC/DC"])
            
            try Artist.fetch(where: Artist.field(.genre) == "Rock", connection: connection)
            
            let result = try connection.execute(selectQuery)
            print(result.first)
            
            XCTAssert(try result.first?.value(Artist.field(.name)) == "Josh Rouse")
        }
        catch {
            print(error)
            throw error
        }
    }
    
    func testUpdate() {
        do {
            let query = Artist.update([.name: "AC/DC"]).filter(Artist.field(.genre) == "Rock")
            
            try connection.execute(query)
        }
        catch {
            XCTFail("Update error: \(error)")
        }
    }
    
    func testModelInsert() throws {
        do {
            var artist = Artist(name: "The Darkness", genre: "Rock")
            try artist.save(connection: connection)
            
            
            artist.name = "The Darkness 2"
            try artist.save(connection: connection)
            
            guard let artistId = artist.id else {
                XCTFail("Failed to set id")
                return
            }
            
            
            
            XCTAssert(try Artist.get(artistId, connection: connection)?.name == "The Darkness 2")
        }
        catch {
            print(error)
            throw error
        }
    }
    
    
    func testEquality() throws {
        do {
            var artist = Artist(name: "Mew", genre: "Alternative")
            try artist.save(connection: connection)
            
            guard let id = artist.id else {
                return XCTFail("Create failed")
            }
            
            let same = try Artist.get(id, connection: connection)
            
            XCTAssert(same == artist)
        }
        catch {
            print(error)
            
        }
    }
    
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        
        connection.close()
        
    }
}


