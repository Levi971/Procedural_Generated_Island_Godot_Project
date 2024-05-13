@tool
extends MeshInstance3D

var Altitude = {}
var Temperature = {}
var Atmosphere = {}

@export var height = 100
@export var width = 100
@export_enum("None","Side_x","Island") var Fall_Off : int
@export var Fall_Off_Multi = 0.5
@export var Alti_Multi = 1.0
@export var Mesh_Alti_Multi = 25

@export var Wide_Terrain_Multi = 1.0

@export var Fall_out_Entree = 0.8
@export var Fall_out_Sortie = 0.4

@export var f : FastNoiseLite
@onready var L = Liste_Biome.new()

@onready var List_2D = [$Code_Couleur/Black_Code,$Code_Couleur/Red_Code,$Code_Couleur/Green_Code,$Code_Couleur/Blue_Code]


@export var Env_Black : int
@export var Env_Red : int
@export var Env_Green : int
@export var Env_Blue : int


@export_global_dir var Lieux_Sauvegarde

var Angle = 0
var Up_Cam = 0
var Point__pivot = Vector3.ZERO


@export var Liste_Prop : Array[PackedScene]
@export var Fill_Grid = 2
@export var Global_Chance_Mode = false
@export_range(0.0,1.0,0.01) var Global_Chance = 0.5

@onready var Carte_Chemin = null


#########################




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	
	Carte_Chemin = Image.create(height,width,false,Image.FORMAT_BPTC_RGBA)
	Carte_Chemin.decompress()
	
	add_child(L)
	if not Engine.is_editor_hint():
	
		
		Point__pivot = Vector3(height/2,height/20,width/2)

		Altitude = Create_Carte(height,width,0.0025,5,2,0,Fall_Off,Alti_Multi)
		Temperature = Create_Carte(height,width,0.001,5,2,1,0,1)
		Atmosphere = Create_Carte(height,width,0.001,5,2,0.5,0,1)
		#
		$Creation_Track.Create_Avec_Prelist(Mesh_Alti_Multi,Altitude)
		#
		
		var Table_Environement = Create_Color_Carte(height,width)
		Adaptation_du_terrain(height,width,6)
		
		Creation_Mesh(height,width)
		Popularisation_Prop(2500,height,width,Table_Environement)
		#$Creation_Track.Create()
		
		Delete_Collision()
		Create_Color_Carte(height,width)
		Creation_Mesh(height,width)
		
		
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	var List_Name_Color = ["Black","Red","Green","Blue"]
	var List_Env = [Env_Black,Env_Red,Env_Green,Env_Blue]
	
	for i in List_2D.size():
		Update_Label_Color(List_2D[i],List_Name_Color[i],List_Env[i])
	
	
	if not Engine.is_editor_hint():
		Angle += (delta/5.0)
		var Up_Down = Input.get_axis("ui_down","ui_up")
		Up_Cam += Up_Down * (delta * 40)
		var UC = Vector3.UP * Up_Cam
		
		
		$Camera3D.global_position = Point__pivot + UC + (basis.x.rotated(Vector3.UP,Angle) * (height/1.5))
		$Camera3D.look_at(Point__pivot)
	pass

func Create_Carte(height : int , width : int ,frequence : float, octave : float , lacun : float, smooth : float , type_fade : int , Multiplicateur : float):
	var GridName = {}
	var Noise_ = FastNoiseLite.new()
	Noise_.frequency = frequence
	Noise_.fractal_octaves = octave
	Noise_.fractal_lacunarity = lacun
	Noise_.fractal_weighted_strength = smooth
	randomize()
	Noise_.seed = randi_range(0,10000)
	
	for x in height:
		for z in width:
			GridName[Vector2(x,z)] = (absf((Noise_.get_noise_2d(x,z) * Alti_Multi)) * clampf(add_Fall_off(Vector2(x,z),height,width,type_fade),0,100))
			#GridName[Vector2(x,z)] = (clampf((Noise_.get_noise_2d(x,z) * Alti_Multi),0,1) * clampf(add_Fall_off(Vector2(x,z),height,width,type_fade),0,100))
			GridName[Vector2(x,z)] = clampf(GridName[Vector2(x,z) ],0,3)
	
	return GridName

func Create_Color_Carte(height : int , width : int):
	print("Begin_Color")
	var Carte = Image.create(height,width,false,Image.FORMAT_BPTC_RGBA)
	Carte.decompress()
	
	#var Carte_Chemin = Image.create(height,width,false,Image.FORMAT_BPTC_RGBA)
	#Carte_Chemin.decompress()
	
	
	var Ray = RayCast3D.new()
	Ray.exclude_parent = false
	Ray.target_position = Vector3(0,-1000,0)
	add_child(Ray)
	
	
	var Table_Environement = {}
	
	for x in height:
		for z in width:
			var Couleur_a_rajouter = Color.BLACK
			var pos = Vector2(x,z)
			
			var alt = Altitude[pos]
			var atm = Atmosphere[pos]
			var tem = Temperature[pos]
			
			
			if beetween(alt,0,0.2):
				Couleur_a_rajouter = Color.BLACK
			
			elif beetween(alt,0.2,0.5):
				if beetween(atm,0.3,1.0):
					Couleur_a_rajouter = Color.RED
				else:
					Couleur_a_rajouter = Color.BLACK
			
			elif  beetween(alt,0.5,1):
				if beetween(atm,0.3,1.0):
					Couleur_a_rajouter = Color.GREEN
				else:
					Couleur_a_rajouter = Color.BLACK
					
			elif  beetween(alt,1,3):
				if beetween(atm,0.5,1.0):
					Couleur_a_rajouter = Color.BLUE
				else:
					Couleur_a_rajouter = Color.BLUE
			###############
			Table_Environement[Vector2(x,z)] = Trad_Couleur_for_Environnement(Couleur_a_rajouter)
			
			var position_du_ray = Vector3(x,200,z)
			Ray.position = position_du_ray
			Ray.force_raycast_update()
			Ray.force_update_transform()
			
			Carte.set_pixelv(pos,Couleur_a_rajouter)
			
			if Ray.is_colliding() and not beetween(alt,0,0.2) and alt > 0:
				#print("touch")
				var new_pos = Vector2()
				new_pos.x = int(pos.x / Wide_Terrain_Multi)
				new_pos.y = int(pos.y / Wide_Terrain_Multi)
				Carte_Chemin.set_pixelv(new_pos,Color.WHITE)
				Altitude[pos] = float(Ray.get_collision_point().y) / float(Mesh_Alti_Multi)
				#
				Table_Environement[Vector2(new_pos.x,new_pos.y)] = Trad_Couleur_for_Environnement(Color.BLUE)
			
			
			#Carte.set_pixelv(pos,Couleur_a_rajouter)
			
	Carte.save_png(Lieux_Sauvegarde + "/Carte.png")
	Carte_Chemin.save_png(Lieux_Sauvegarde + "/Carte_Chemin.png")
	
	var I = ImageTexture.new()
	I.set_image(Carte)
	
	var IC = ImageTexture.new()
	IC.set_image(Carte_Chemin)
	
	#get_surface_override_material(0).albedo_texture = I
	get_surface_override_material(0).set("shader_parameter/Carte",I)
	get_surface_override_material(0).set("shader_parameter/Carte_Path",IC)
	
	return Table_Environement

func beetween(val : float , min_ : float , max_ : float):
	if val >= min_ and val <= max_:
		return true
	else:
		false

func add_Fall_off(position_ : Vector2 , height : int , width : int , type : int):
	if type == 0:
		return 1
	
	if type == 1:
		var x = float(position_.x) / float(height)
		if x < Fall_out_Entree:
			var c = x
			x = inverse_lerp(Fall_out_Sortie,Fall_out_Entree,x) * c
		#else:
			#x = 1
		return x 
	
	if type == 2:
		var x_r = float(position_.x) / float(height - 1)
		var z_r = float(position_.y) / float(width - 1)
		
		var pos = Vector2(x_r,z_r)
		var center = Vector2(0.5,0.5)
			
		var total = 0
		var divisor = 2.0
		#var power = 1

		total = 1 - center.distance_to(pos)
		#total = pow(total,power)
		
		if total < Fall_out_Entree:
			var c = total
			total = inverse_lerp(Fall_out_Sortie,Fall_out_Entree,total) #* c
		else:
			total = 1
		
		return total

func Creation_Mesh(height : int , width : int ):
	var Arr = PackedVector3Array()
	var Uv_Arr = PackedVector2Array()

	
	for x in height - 1:
		for z in width - 1:
			var Alt_Mult = Mesh_Alti_Multi
			var Wide_Multi = Wide_Terrain_Multi
			
			
			
			Arr.push_back(Vector3(x * Wide_Multi,Altitude[Vector2(x,z)] * Alt_Mult,z* Wide_Multi))
			Uv_Arr.push_back(Vector2(float(x)/ float(height)  , float(z)/ float(width)))
			
			Arr.push_back(Vector3((x + 1) * Wide_Multi,Altitude[Vector2(x +1,z)] * Alt_Mult,z * Wide_Multi))
			Uv_Arr.push_back(Vector2(float(x + 1)/ float(height)  , float(z)/ float(width)))
			
			Arr.push_back(Vector3(x* Wide_Multi,Altitude[Vector2(x,z + 1)] * Alt_Mult,(z + 1)* Wide_Multi))
			Uv_Arr.push_back(Vector2(float(x)/ float(height)  , float(z + 1)/ float(width)))
			
			#########################
			Arr.push_back(Vector3(x* Wide_Multi,Altitude[Vector2(x,z + 1)] * Alt_Mult,(z + 1) * Wide_Multi))
			Uv_Arr.push_back(Vector2(float(x)/ float(height)  , float(z + 1)/ float(width)))
			
			Arr.push_back(Vector3((x + 1)* Wide_Multi,Altitude[Vector2(x + 1,z)] * Alt_Mult,z* Wide_Multi))
			Uv_Arr.push_back(Vector2(float(x + 1)/ float(height)  , float(z)/ float(width)))
			
			Arr.push_back(Vector3((x + 1) * Wide_Multi,Altitude[Vector2(x + 1,z + 1)] * Alt_Mult,(z + 1)* Wide_Multi))
			Uv_Arr.push_back(Vector2(float(x + 1)/ float(height)  , float(z + 1)/ float(width)))
			
			
			
			
	
	
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = Arr
	arrays[Mesh.ARRAY_TEX_UV] = Uv_Arr
	
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh = arr_mesh

	var Surf = SurfaceTool.new()
	Surf.create_from(mesh,0)
	
	Surf.generate_tangents()
	Surf.generate_normals()
	
	mesh = Surf.commit()
	create_trimesh_collision()
	
	pass

func Update_Label_Color(Hb : HBoxContainer, Couleur : String, Env : int):
	Hb.get_child(0).text = str(Couleur," : ")
	Hb.get_child(1).text = str(L.Liste_des_environement[Env])
	pass

func Trad_Couleur_for_Environnement(Couleur : Color):
	if Couleur == Color.BLACK:
		return Env_Black
	elif Couleur == Color.RED:
		return Env_Red
	elif Couleur == Color.GREEN:
		return Env_Green
	elif Couleur == Color.BLUE:
		return Env_Blue

func Popularisation_Prop(Limit : int , height : int ,width : int , Liste_Environemental : Dictionary):
	var Liste = []
	var Liste_Alt_Min = []
	
	for i in Liste_Prop.size():
		var Obj = Liste_Prop[i].instantiate()
		#add_child(Obj)
		if Obj is Prop_Terrain:
			Liste.append(Obj) #.Environnement
			Liste_Alt_Min.append(Obj.Start)
			print(Obj.Environnement,"   ",Obj.Start)
		pass
	
	var Nmb_Obj_Placé = 0
	
	for x in range(0,height,Fill_Grid) :
		for y in range(0,width,Fill_Grid):
			
			randomize()
			var extra_x = randi_range(-50,50)
			var extra_y = randi_range(-50,50)
			
			var total_x = x + extra_x
			var total_y = y + extra_y
			
			total_x = clampi(total_x,0,height - 1)
			total_y = clampi(total_y,0,width - 1)
			
			if Nmb_Obj_Placé <= Limit:
				var pos =  Vector2(total_x,total_y)
				
				var Liste_Posibilité = []
				var Alt = Altitude[pos]
				
				
				for i in Liste.size():
					#print(Liste[i].Environnement ," in ",Liste_Environemental[pos])
					#print(Liste[i].Start ," in ", Alt)
					
					if Liste[i].Environnement == Liste_Environemental[pos] and Liste[i].Start <= Alt and Liste[i].End >= Alt:
						#print("Accepté")
						#print(Liste[i].Start ," in ", Alt)
						Liste_Posibilité.append(Liste[i])
					#else:
						#print("Refusé")
				
				
				if Liste_Posibilité.size() != 0:
					randomize()
					
					
					var Choosen = Liste_Posibilité.pick_random().duplicate()
					
					var Drop = randf_range(0,1)
					if (Drop <= Choosen.Chance_Drop and not Global_Chance_Mode) or (Drop <= Global_Chance and Global_Chance_Mode):
						add_child(Choosen)
						#print("Choosen :",Choosen)
						
						Choosen.global_position = Vector3((total_x * Wide_Terrain_Multi), (Alt * Mesh_Alti_Multi) ,(total_y * Wide_Terrain_Multi))
						randomize()
						var Sca = randf_range(Choosen.Scale_Min,Choosen.Scale_Max)
						Choosen.scale = Vector3(Sca,Sca,Sca)
						Choosen.rotation_degrees.y = randf_range(-180,180)
						
						Nmb_Obj_Placé += 1
	pass

func Adaptation_du_terrain(height : int ,width : int , smooth_square : int):
	var New_Alt = {}
	var Changed_Reference = PackedVector2Array()
	for x in height - 1:
		for y in width - 1:
			var pos = Vector2(x,y)
			var Total_Alt = 0
			var Nombre_T = 0
			
			for xx in range(-(smooth_square/2),smooth_square/2):
				for yy in range(-(smooth_square/2),smooth_square/2):
					var nx = clampf(x + xx , 0 , height - 1)
					var ny = clampf(y + yy , 0 , width - 1)
					var new_pos = Vector2(nx,ny)
					Total_Alt += Altitude[new_pos]
					Nombre_T += 1
			
			Changed_Reference.append(Vector2(x,y))
			New_Alt[Vector2(x,y)] = Total_Alt / float(Nombre_T)
			
			pass
	for i in Changed_Reference.size():
		Altitude[Changed_Reference[i]] = New_Alt[Changed_Reference[i]]

func Delete_Collision():
	var all_child = get_children()
	for i in all_child.size():
		if all_child[i] is StaticBody3D:
			remove_child(all_child[i])
