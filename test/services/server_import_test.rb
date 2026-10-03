require "test_helper"

class ServerImportTest < ActiveSupport::TestCase
  def parse(text, format: "csv", **options) = ServerImport.parse(text, format: format, **options)

  test "CSV with a header, in any column order, French names and accents" do
    rows = parse(<<~CSV)
      utilisateur,Hôte,Nom,groupes,port
      deploy,10.0.0.12,API,Production|API,2222
      ,api2.example.com,API 2,,
    CSV

    assert_equal [ 2, "API", "10.0.0.12", 2222, "deploy", [ "Production", "API" ], :valid ], rows.first.to_h.values_at(:line, :name, :host, :port, :username, :group_names).push(rows.first.status)
    assert_equal [ 3, "api2.example.com", 22, "root", [] ], [ rows.last.line, rows.last.host, rows.last.port, rows.last.username, rows.last.group_names ]
  end

  test "CSV without header uses name, host, port, user, groups; ; separated files work" do
    rows = parse("API;10.0.0.12;;admin;Prod, Clients ;prod\n\nDB;10.0.0.13\n", default_username: "debian")

    assert_equal [ "API", "10.0.0.12", 22, "admin" ], rows.first.to_h.values_at(:name, :host, :port, :username)
    assert_equal [ "Prod", "Clients" ], rows.first.group_names, "split on , ; | and deduplicated"
    assert_equal [ 3, "debian" ], [ rows.last.line, rows.last.username ]
  end

  test "flags invalid rows with the Server errors" do
    rows = parse("Bad,not a host!,99999,root\n,10.0.0.1\nLong,10.0.0.2,22,root,#{"g" * 51}\n")

    assert_equal [ :invalid ] * 3, rows.map(&:status)
    assert_match "Hôte", rows.first.errors.join
    assert_match "Port", rows.first.errors.join
    assert_match "Nom", rows.second.errors.join
    assert_match "trop long", rows.third.errors.join
  end

  test "flags duplicates of existing servers (name or address) and within the file" do
    rows = parse("web,10.9.9.9\nOther,192.168.1.10,22\nNew,10.0.0.50\nnew,10.0.0.51\nPort,192.168.1.10,2200\n")

    assert_equal [ :duplicate, :duplicate, :valid, :duplicate, :valid ], rows.map(&:status)
    assert_equal [ "Web", "Web", nil, "New", nil ], rows.map(&:duplicate_of)
  end

  test "ssh config: one server per concrete Host, defaults, patterns and Match skipped" do
    rows = parse(<<~CONFIG, format: "ssh_config", default_username: "admin")
      # personal servers
      Host *
        User nobody
      Host bastion b2
        HostName bastion.example.com
        Port 2222
      Host db
        User=postgres # inline comment
      Host web-*
        User x
      Match host foo
        User bar
      Host api
        hostname 10.0.0.12
    CONFIG

    assert_equal [ [ 4, "bastion", "bastion.example.com", 2222, "admin" ], [ 7, "db", "db", 22, "postgres" ], [ 13, "api", "10.0.0.12", 22, "admin" ] ],
                 rows.map { |row| [ row.line, row.name, row.host, row.port, row.username ] }
  end

  test "refuses empty, unknown, oversized, non UTF-8 or malformed input" do
    { "" => "Collez", "\n\n" => "Collez", "Host *\n" => "Aucun serveur" }.each do |text, message|
      assert_match message, assert_raises(ServerImport::Error) { parse(text, format: "ssh_config") }.message
    end
    assert_raises(ServerImport::Error) { parse("a,b", format: "xml") }
    assert_match "trop gros", assert_raises(ServerImport::Error) { parse("a" * (ServerImport::MAX_SIZE + 1)) }.message
    assert_match "UTF-8", assert_raises(ServerImport::Error) { parse("caf\xE9,10.0.0.1".b) }.message
    assert_match "CSV invalide", assert_raises(ServerImport::Error) { parse("a,\"b\n") }.message
    assert_match "Trop de lignes", assert_raises(ServerImport::Error) { parse((1..501).map { |n| "s#{n},10.0.0.1" }.join("\n")) }.message
  end

  test "a UTF-8 BOM is ignored" do
    assert_equal "API", parse("﻿nom,hôte\nAPI,10.0.0.12").first.name
  end

  test "import! creates the valid rows and their missing groups, reusing existing ones" do
    rows = parse("A,10.0.0.1,22,root,production|Clients\nB,10.0.0.2,22,root,clients\nweb,10.0.0.3\nbad,\n")

    servers = assert_difference -> { Server.count } => 2, -> { ServerGroup.count } => 1 do
      ServerImport.import!(rows)
    end

    assert_equal %w[A B], servers.map(&:name)
    assert_equal [ "Clients", "Production" ], servers.first.reload.server_groups.map(&:name)
    assert_equal servers.first.server_groups.find_by(name: "Clients"), servers.last.server_groups.sole
    assert_includes server_groups(:production).servers, servers.first
  end
end
