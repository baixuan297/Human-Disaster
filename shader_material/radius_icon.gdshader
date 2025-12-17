shader_type canvas_item;

// 纹理的尺寸
uniform vec2 texture_size;
// 圆半径
uniform float radius;

// 判断是否在圆内
bool check(vec2 texCoord) {
	vec2 pos = vec2(texCoord.x*texture_size.x, (1.0 - texCoord.y)*texture_size.y);
	if (pow(pos.x - texture_size.x*0.5, 2.0) + pow(pos.y - texture_size.y*0.5, 2.0) <= pow(radius, 2.0)){
	    return true;
	} else {
	    return false;
	}
}

void fragment(){
	vec4 o = texture(TEXTURE, UV);
    if(!check(UV)) {
		//不在圆内则透明
      o *= vec4(0, 0, 0, 0);
    }
    COLOR = o;
}
