extends BaseBarrelEffect

@export var force: float

# TBH, it should be on_projectile_spawn, but that can get
# out of hand quickly with multishot weapon

const VERTICAL_COEFFICIENT = 0.2

func on_ammo_consumed():
    var backward_direction = GameManager.player.transform.basis.z

    # If the player is looking downward (negative local Y axis points up)
    if GameManager.player.player_camera.transform.basis.z.y > 0:
        # Add upward force component to the backward direction
        backward_direction += Vector3(0, 1, 0) * VERTICAL_COEFFICIENT
        backward_direction = backward_direction.normalized()

    GameManager.player.apply_impulse_to_player(backward_direction * force)
