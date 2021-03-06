-module(sw_core_db).

-include("sw_core_db.hrl").
-export([load/2]).
-export([wait_for_tables/0]).

-export([create_schema/0]).

%% tag::recordOf[]
record_of('Film') -> film;
record_of('Person') -> person;
record_of('Planet') -> planet;
record_of('Species') -> species;
record_of('Starship') -> starship;
record_of('Transport') -> transport;
record_of('Vehicle') -> vehicle.
%% end::recordOf[]

tables() ->
    [starship, transport, film,
     species, person, planet, vehicle].

wait_for_tables() ->
    mnesia:wait_for_tables([sequences | tables()], 5000).

load('Vehicle', ID) ->
    F = fun() ->
                [Transport] = mnesia:read('Transport', ID, read),
                [Vehicle]  = mnesia:read('Vehicle', ID, read),
                #{ starship => Vehicle,
                   transport => Transport }
        end,
    txn(F);
%% tag::loadStarship[]
load('Starship', ID) ->
    F = fun() ->
                [Transport] = mnesia:read('Transport', ID, read),
                [Starship]  = mnesia:read('Starship', ID, read),
                #{ starship => Starship,
                   transport => Transport }
        end,
    txn(F);
%% end::loadStarship[]
%% tag::load[]
load(Type, ID) ->
    MType = record_of(Type),
    F = fun() ->
                [Obj] = mnesia:read(MType, ID, read),
                Obj
        end,
    txn(F).

%% @doc txn/1 turns a mnesia transaction into a GraphQL friendly return
%% @end
txn(F) ->
    case mnesia:transaction(F) of
        {atomic, Res} -> {ok, Res};
        {aborted, Reason} -> {error, Reason}
    end.
%% end::load[]

%% @doc Create the backend schema for the SW system
%% @end
%% tag::createSchema[]
create_schema() ->
    mnesia:create_schema([node()]),
    application:ensure_all_started(mnesia),
    ok = create_tables(),
    ok = populate_tables(),
    mnesia:backup("FALLBACK.BUP"),
    mnesia:install_fallback("FALLBACK.BUP"),
    application:stop(mnesia).
%% end::createSchema[]
%% tag::createTables[]
create_tables() ->
    {atomic, ok} =
        mnesia:create_table(
          starship,
          [{disc_copies, [node()]},
           {type, set},
           {attributes, record_info(fields, starship)}]),
    {atomic, ok} =
        mnesia:create_table(
          species,
          [{disc_copies, [node()]},
           {type, set},
           {attributes, record_info(fields, species)}]),
%% end::createTables[]
    {atomic, ok} =
        mnesia:create_table(
          film,
          [{disc_copies, [node()]},
           {type, set},
           {attributes, record_info(fields, film)}]),
    {atomic, ok} =
        mnesia:create_table(
          person,
          [{disc_copies, [node()]},
           {type, set},
           {attributes, record_info(fields, person)}]),
    {atomic, ok} =
        mnesia:create_table(
          planet,
          [{disc_copies, [node()]},
           {type, set},
           {attributes, record_info(fields, planet)}]),
    {atomic, ok} =
        mnesia:create_table(
          transport,
          [{disc_copies, [node()]},
           {type, set},
           {attributes, record_info(fields, transport)}]),
    {atomic, ok} =
        mnesia:create_table(
          vehicle,
          [{disc_copies, [node()]},
           {type, set},
           {attributes, record_info(fields, vehicle)}]),
    {atomic, ok} =
        mnesia:create_table(
          sequences,
          [{disc_copies, [node()]},
           {type, set},
           {attributes, record_info(fields, sequences)}]),
    ok.

%% tag::populatingTables[]
populate(File, Fun) ->
    {ok, Data} = file:read_file(File),
    Terms = jsx:decode(Data, [return_maps]),
    Fun(Terms).

populate_tables() ->
    populate("fixtures/transport.json", fun populate_transports/1),
    populate("fixtures/starships.json", fun populate_starships/1),
    populate("fixtures/species.json", fun populate_species/1),
    populate("fixtures/films.json", fun populate_films/1),
    populate("fixtures/people.json", fun populate_people/1),
    populate("fixtures/planets.json", fun populate_planets/1),
    populate("fixtures/vehicles.json", fun populate_vehicles/1),
    setup_sequences(),
    ok.
%% end::populatingTables[]

%% tag::populateTransports[]
populate_transports(Ts) ->
    Transports = [json_to_transport(T) || T <- Ts],
    Txn = fun() ->
                [mnesia:write(S) || S <- Transports],
                ok
          end,
    {atomic, ok} = mnesia:transaction(Txn),
    ok.
%% end::populateTransports[]

setup_sequences() ->
    Counters = [#sequences { key = K, value = 1000 } || K <- tables()],
    Txn = fun() ->
                  [mnesia:write(C) || C <- Counters],
                  ok
          end,
    {atomic, ok} = mnesia:transaction(Txn),
    ok.

populate_starships(Terms) ->
    Starships = [json_to_starship(T) || T <- Terms],
    Txn = fun() ->
                  [mnesia:write(F) || F <- Starships],
                  ok
          end,
    {atomic, ok} = mnesia:transaction(Txn),
    ok.

populate_films(Terms) ->
    Films = [json_to_film(T) || T <- Terms],
    Txn = fun() ->
                  [mnesia:write(F) || F <- Films],
                  ok
          end,
    {atomic, ok} = mnesia:transaction(Txn),
    ok.

populate_species(Terms) ->
    Species = [json_to_species(T) || T <- Terms],
    Txn = fun() ->
                [mnesia:write(S) || S <- Species],
                ok
          end,
    {atomic, ok} = mnesia:transaction(Txn),
    ok.

populate_people(Terms) ->
    People = [json_to_person(P) || P <- Terms],
    Txn = fun() ->
                  [mnesia:write(P) || P <- People],
                  ok
          end,
    {atomic, ok} = mnesia:transaction(Txn),
    ok.

%% tag::populate_planets[]
populate_planets(Terms) ->
    People = [json_to_planet(P) || P <- Terms],
    Txn = fun() ->
                  [mnesia:write(P) || P <- People],
                  ok
          end,
    {atomic, ok} = mnesia:transaction(Txn),
    ok.
%% end::populate_planets[]

populate_vehicles(Terms) ->
    Vehicles = [json_to_vehicle(V) || V <- Terms],
    Txn = fun() ->
                  [mnesia:write(V) || V <- Vehicles],
                  ok
          end,
    {atomic, ok} = mnesia:transaction(Txn),
    ok.

%% tag::jsonToTransport[]
json_to_transport(
  #{ <<"pk">> := ID,
     <<"fields">> := #{
         <<"edited">> := Edited,
         <<"consumables">> := Consumables,
         <<"name">> := Name,
         <<"created">> := Created,
         <<"cargo_capacity">> := CargoCapacity,
         <<"passengers">> := Passengers,
         <<"max_atmosphering_speed">> := MaxAtmosSpeed,
         <<"crew">> := Crew,
         <<"length">> := Length,
         <<"model">> := Model,
         <<"cost_in_credits">> := Cost,
         <<"manufacturer">> := Manufacturer }}) ->
    #transport {
       id = ID,
       cargo_capacity = CargoCapacity,
       consumables = Consumables,
       cost = Cost,
       created = Created,
       crew = Crew,
       edited = Edited,
       length = Length,
       manufacturers = [Manufacturer],
       max_atmosphering_speed = MaxAtmosSpeed,
       model = Model,
       name = Name,
       passengers = Passengers }.
%% end::jsonToTransport[]

json_to_starship(
  #{ <<"pk">> := ID,
     <<"fields">> := #{
         <<"pilots">> := Pilots,
         <<"MGLT">> := MGLT,
         <<"starship_class">> := Class,
         <<"hyperdrive_rating">> := HyperRating
        }}) ->
    #starship {
       id = ID,
       pilots = Pilots,
       mglt = MGLT,
       starship_class = Class,
       hyperdrive_rating = HyperRating
      }.

json_to_film(
  #{ <<"pk">> := ID,
     <<"fields">> := #{
         <<"edited">> := Edited,
         <<"created">> := Created,
         <<"vehicles">> := Vehicles,
         <<"planets">> := Planets,
         <<"producer">> := Producer,
         <<"title">> := Title,
         <<"episode_id">> := EpisodeId,
         <<"director">> := Director,
         <<"opening_crawl">> := OpeningCrawl,
         <<"characters">> := Characters
        }}) ->
    #film {
       id = ID,
       edited = Edited,
       created = Created,
       vehicles = Vehicles,
       planets = Planets,
       producer = Producer,
       title = Title,
       episode_id = EpisodeId,
       director = Director,
       opening_crawl = OpeningCrawl,
       characters = Characters
      }.
  
json_to_species(
  #{ <<"pk">> := ID,
     <<"fields">> := #{
         <<"edited">> := Edited,
         <<"classification">> := Classification,
         <<"name">> := Name,
         <<"created">> := Created,
         <<"eye_colors">> := EyeColors,
         <<"people">> := People,
         <<"skin_colors">> := SkinColors,
         <<"language">> := Language,
         <<"hair_colors">> := HairColors,
         <<"homeworld">> := HomeWorld,
         <<"average_lifespan">> := LifeSpan,
         <<"average_height">> := Height }}) ->
    #species {
       id = ID,
       edited = Edited,
       created = Created,
       classification = Classification,
       name = Name,
       eye_colors = commasplit(EyeColors),
       people = People,
       skin_colors = commasplit(SkinColors),
       language = Language,
       hair_colors = commasplit(HairColors),
       homeworld = HomeWorld,
       average_lifespan = integer_like(LifeSpan),
       average_height = integer_like(Height) }.

%% tag::json_to_planet[]
json_to_planet(
  #{ <<"pk">> := ID,
     <<"fields">> := #{
         <<"edited">> := Edited,
         <<"climate">> := Climate,
         <<"surface_water">> := SWater,
         <<"name">> := Name,
         <<"diameter">> := Diameter,
         <<"rotation_period">> := RotationPeriod,
         <<"created">> := Created,
         <<"terrain">> := Terrain,
         <<"gravity">> := Gravity,
         <<"orbital_period">> := OrbPeriod,
         <<"population">> := Population
        }}) ->
    #planet {
       id = ID,
       edited = Edited,
       climate = Climate,
       surface_water = SWater,
       name = Name,
       diameter = Diameter,
       rotation_period = RotationPeriod,
       created = Created,
       terrain = Terrain,
       gravity = Gravity,
       orbital_period = OrbPeriod,
       population = Population
}.
%% end::json_to_planet[]

json_to_person(
  #{ <<"pk">> := ID,
     <<"fields">> := #{
         <<"edited">> := Edited,
         <<"name">> := Name,
         <<"created">> := Created,
         <<"gender">> := Gender,
         <<"skin_color">> := SkinColor,
         <<"hair_color">> := HairColor,
         <<"height">> := Height,
         <<"eye_color">> := EyeColor,
         <<"mass">> := Mass,
         <<"homeworld">> := HomeWorld,
         <<"birth_year">> := BirthYear
        }}) ->
    #person {
       id = ID,
       edited = Edited,
       name = Name,
       created = Created,
       gender = Gender,
       skin_color = SkinColor,
       hair_color = HairColor,
       height = Height,
       eye_color = EyeColor,
       mass = Mass,
       homeworld = HomeWorld,
       birth_year = BirthYear
      }.

json_to_vehicle(
  #{ <<"pk">> := ID,
     <<"fields">> := #{
         <<"vehicle_class">> := Class,
         <<"pilots">> := Pilots
        }}) ->
    #vehicle {
       id = ID,
       vehicle_class = Class,
       pilots = Pilots
      }.

%% --- INTERNAL HELPERS ------------------------
commasplit(String) ->
    binary:split(String, <<", ">>, [global]).

integer_like(<<"indefinite">>) -> infinity;
integer_like(<<"n/a">>)        -> nan;
integer_like(<<"unknown">>)    -> nan;
integer_like(String)           -> binary_to_integer(String).

