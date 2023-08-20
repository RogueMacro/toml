using System;
using System.Collections;
using Serialize;

namespace Toml.Tests
{
	class Example
	{
		public static String ExampleDocumentText =
			"""
			# This is a TOML document.

			testprop = { d = "2" }

			title = "TOML Example"

			[owner]
			name = "Tom Preston-Werner"
			dob = 1979-05-27T07:32:00-08:00 # First class dates

			[database]
			server = "192.168.1.1"
			ports = [ 8000, 8001, 8002 ]
			connection_max = 5000
			enabled = true

			[servers]

			  # Indentation (tabs and/or spaces) is allowed but not required
			  [servers."alpha-0"]
			  ip = "10.0.0.1"
			  dc = "eqdc10"

			  [servers.beta]
			  ip = "10.0.0.2"
			  dc = "eqdc10"

			[clients]
			#data = [ ["gamma", "delta"], [1, 2] ]

			# Line breaks are OK when inside arrays
			hosts = [
			  "alpha",
			  "omega"
			]
			""";


		[Test]
		public static void StandardExample()
		{
			let serializer = scope Serializer<Toml>();
			let result = serializer.Deserialize<ExampleDocument>(ExampleDocumentText);
			if (result case .Err)
			{
				Console.WriteLine("Error: {}", serializer.Error);
				//Test.Assert(false);
				Console.Read().IgnoreError();
			}

			let document = result.Get();
			defer delete document;

			Test.Assert(document.title == "TOML Example");

			Test.Assert(document.owner.name == "Tom Preston-Werner");
			Test.Assert(document.owner.dob == .(1979, 5, 27, 15, 32, 0));

			Test.Assert(document.database.server == "192.168.1.1");
			Test.Assert(document.database.ports.Count == 3);
			Test.Assert(document.database.ports[0] == 8000);
			Test.Assert(document.database.ports[1] == 8001);
			Test.Assert(document.database.ports[2] == 8002);
			Test.Assert(document.database.connection_max == 5000);
			Test.Assert(document.database.enabled == true);

			Test.Assert(document.servers.Count == 2);
			Test.Assert(document.servers["alpha-0"].ip == "10.0.0.1");
			Test.Assert(document.servers["alpha-0"].dc == "eqdc10");
			Test.Assert(document.servers["beta"].ip == "10.0.0.2");
			Test.Assert(document.servers["beta"].dc == "eqdc10");

			Test.Assert(document.clients.hosts.Count == 2);
			Test.Assert(document.clients.hosts[0] == "alpha");
			Test.Assert(document.clients.hosts[1] == "omega");

			String str = scope .();
			serializer.Serialize(document, str);
			Console.WriteLine(str);
			Console.Read().IgnoreError();
		}

		[Serializable]
		class ExampleDocument
		{
			public TestEnum testprop ~ if (testprop case .Str(let val)) delete val;
			public String title ~ delete _;
			public Owner owner ~ delete _;
			public Database database ~ delete _;
			public Dictionary<String, Server> servers ~ DeleteDictionaryAndKeysAndValues!(_);
			public Clients clients ~ delete _;
		}

		[Serializable]
		enum TestEnum
		{
			case Str(String d);
			case Int(int i);
		}

		[Serializable]
		class Owner
		{
			public String name ~ delete _;
			public DateTime dob;
		}

		[Serializable]
		class Database
		{
			public String server ~ delete _;
			public List<int> ports ~ delete _;
			public int connection_max;
			public bool enabled;
		}

		[Serializable]
		class Server
		{
			public String ip ~ delete _;
			public String dc ~ delete _;
		}

		[Serializable]
		class Clients
		{
			public List<String> hosts ~ DeleteContainerAndItems!(_);
		}
	}
}