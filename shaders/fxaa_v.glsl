//GLSL
#version 140
in vec2 p3d_MultiTexCoord0;
in vec4 p3d_Vertex;
uniform mat4 p3d_ModelViewProjectionMatrix;
uniform float FXAA_SUBPIX_SHIFT = 1.0/4.0;
uniform vec2 win_size;
out vec4 posPos;

void main()
    {
    gl_Position = p3d_ModelViewProjectionMatrix * p3d_Vertex;
    vec2 rcpFrame = vec2(1.0/win_size.x, 1.0/win_size.y);
    posPos.xy = p3d_MultiTexCoord0.xy;
    posPos.zw = p3d_MultiTexCoord0.xy - (rcpFrame * (0.5 + FXAA_SUBPIX_SHIFT));
    }