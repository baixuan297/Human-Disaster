extends RefCounted
class_name PlayerViewPaths

## Fish_Man 上第三人称与 TP 瞄准路径的唯一来源（改 `ThirdPersonCameraRig.tscn` 时同步改此文件与 `PLAYER_CAMERA_AND_MOVEMENT.md`）。

const THIRD_PERSON_RIG: NodePath = ^"thirdperson"
const _STR_TP_TO_CAM := "thirdperson/Yaw/Pitch/SpringArm3D/Camera3D"
const THIRD_PERSON_CAMERA: NodePath = NodePath(_STR_TP_TO_CAM)
const THIRD_PERSON_AIMRAY: NodePath = NodePath(_STR_TP_TO_CAM + "/Aimray")
const THIRD_PERSON_AIMRAY_END: NodePath = NodePath(_STR_TP_TO_CAM + "/aimrayend")

const TP_REL_YAW := "Yaw"
const TP_REL_PITCH := TP_REL_YAW + "/Pitch"
const TP_REL_SPRING_ARM := TP_REL_PITCH + "/SpringArm3D"
