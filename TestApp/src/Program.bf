using System;
using System.Collections;
using Serialize;
using Toml;

namespace TestApp
{
    class Program
    {
		[Serializable]
		class Data
		{
			public int Port;
			public String Name ~ delete _;
			public bool Active;
			//public List<int> Ports = new .() { 8000, 8080, 42 } ~ delete _;
			//public Dictionary<String, Server> Servers ~ DeleteDictionaryAndKeysAndValues!(_);
		}

		[Serializable]
		class Server
		{
			public Dictionary<String, User> Users ~ DeleteDictionaryAndKeysAndValues!(_);
		}

		[Serializable]
		class User
		{
			//public String Name ~ delete _;
			public bool Admin;
		}

		[Serializable]
		class BeefSpace
		{
			public int FileVersion = 1;
			public List<String> Locked ~ DeleteContainerAndItems!(_);
			public Dictionary<String, ProjectEntry> Projects ~ DeleteDictionaryAndKeysAndValues!(_);
			public Dictionary<String, List<String>> WorkspaceFolders ~ {
				if (_ != null)
				{
					for (var value in _)
					{
						delete value.key;
						DeleteContainerAndItems!(value.value);
					}
					delete _;
				}
			}
			public Workspace Workspace ~ delete _;
		}

		[Serializable]
		class ProjectEntry
		{
			public String Path ~ delete _;
		}

		[Serializable]
		class Workspace
		{
			public String StartupProject ~ delete _;
		}

		[Serializable]
		class Manifest
		{
			public Package Package = new .() ~ delete _;
		}

		[Serializable]
		class Package
		{
			public String Name = new .("TestApp") ~ delete _;
			public String Version = new .("0.1.0") ~ delete _;
			public String Description = new .() ~ delete _;

			public Dictionary<String, Dependency> Dependencies = new .() {
				(new .("Toml"), new .("..")),
				(new .("Serialize"), new .("../../Serialize"))
			} ~ DeleteDictionaryAndKeysAndValues!(_);
		}

		[Serializable]
		class Dependency
		{
			public String Path ~ delete _;

			public this() {}

			public this(StringView path)
			{
				Path = new .(path);
			}
		}

        public static int Main(String[] args)
        {
			Data data = scope .()
				{
					Port = 42,
				  	Name = new .("Server\n")
				};
			//{
			//	Servers = new .() {
			//		(new $"Server1", new .() {
			//			Users = new .() {
			//				(new .("John"), new .() { Admin = true }),
			//				(new .("Steve"), new .() { Admin = false })
			//			}
			//		}),
			//	}
			//};

			BeefSpace beefspace = scope .() {
				Locked = new .() { new .("corlib") },
				Projects = new .() {
					(new .("corlib"), new .() { Path = new .("C:\\Users\\Willi\\AppData\\Local\\BeefLang\\BeefLibs\\corlib") }),
					(new .("Toml"), new .() { Path = new .(".") })
				},
				WorkspaceFolders = new .() {
					(new .("Packages"), new .())
				}
				Workspace = new .() {
					StartupProject = new .("Toml")
				}
			};

			Manifest manifest = scope .();

			Serialize<Toml> serializer = scope .();
			//let str = serializer.Serialize(data, .. scope String());
			//Console.WriteLine(str);

			String str = scope
				$"""
				Port = 42
				Name = "Server1"
				""";

			let r = serializer.Deserialize<Data>(str);
			if (r case .Err)
			{
				Console.WriteLine("Error: {}", serializer.Error);
				Console.Read().IgnoreError();
				return -1;
			}

			let deserialized = r.Value;

			let str2 = serializer.Serialize(deserialized, .. scope .());
			Console.WriteLine(str2);
			Console.Read();
            return 0;
        }
    }
}
    