extends CharacterBody2D

class_name Player

var speed := 250
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

# TAMBAHKAN FUNGSI INI
func _ready() -> void:
	# Menambahkan Player ke grup "actors" agar bisa dideteksi oleh NPC
	add_to_group("actors")

func _physics_process(delta):
	var velocity = Vector2.ZERO

	if Input.is_action_pressed("walk_right"):
		velocity.x += 1
	if Input.is_action_pressed("walk_left"):
		velocity.x -= 1
	if Input.is_action_pressed("walk_down"):
		velocity.y += 1
	if Input.is_action_pressed("walk_up"):
		velocity.y -= 1

	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
		play_animation(velocity)
	else:
		anim_sprite.stop()

	self.velocity = velocity
	move_and_slide()

func play_animation(velocity: Vector2):
	if abs(velocity.x) > abs(velocity.y):
		if velocity.x > 0:
			anim_sprite.play("walk_right")
		else:
			anim_sprite.play("walk_left")
	else:
		if velocity.y > 0:
			anim_sprite.play("walk_front")
		else:
			anim_sprite.play("walk_back")


func _on_button_pressed() -> void:
	pass # Replace with function body.
