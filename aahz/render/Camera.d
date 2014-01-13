module aahz.render.Camera;

import aahz.render.Interfaces;
import aahz.render.Mixins;
import aahz.render.Model;
import aahz.render.Light;
import aahz.draw.Color;
import aahz.math.Vector;
import aahz.math.Euler;
import aahz.math.Matrix;
import aahz.math.Quaternion;

import derelict.opengl.gl;
import derelict.opengl.glu;

enum CameraStyle {
	NORMAL = 0,
	COLORS = 0x1,
	LIGHTING = 0x2,
	TEXTURES = 0x4
}

class Camera : IBase, ISituatable {
private:
	CameraStyle m_style;
	Model[ Model ] m_models;
	Light[ Light ] m_lights;

public:
	float fov = 40.0f;
	float near = 0.5f, far = 200.0f;
	Color4f ambientLight;
	
	static const Vector INITIAL_FORWARD = { x:0.0f, y:0.0f, z:-1.0f };
	static const Vector INITIAL_UP = { x:0.0f, y:0.0f, z:-1.0f };
	
	this(CameraStyle s = CameraStyle.NORMAL) {
		m_style = s;
		ambientLight.set(0.2f, 0.2f, 0.2f);
	}
	
	mixin VPositioned;
	mixin QRotated;
	
	Matrix getMatrix() {
		Matrix ret = rotation.getMatrix();
		ret.setTranslation(position);
		ret = ret.getInverse();

		return ret;
	}
	
	void add(Model m) {
		m_models[ m ] = m;
	}
	
	void remove(Model m) {
		m_models.remove( m );
	}
	
	void add(Light l) {
		if (m_lights.length == Light.MAX_LIGHTS) return;	// ignore if it's too much
		
		m_lights[ l ] = l;
	}
	
	void remove(Light l) {
		m_lights.remove( l );
	}
	
	void render() {
		Color4f white = {1.0f, 1.0f, 1.0f, 1.0f};
		Color4f black = {0.0f, 0.0f, 0.0f, 1.0f};
		float[1] lightingShininess = [ 50.0f ];
		
		switch (m_style) {
		case CameraStyle.NORMAL:
			glEnableClientState(GL_VERTEX_ARRAY);
			scope (exit) glDisableClientState(GL_VERTEX_ARRAY);
			
			glEnable(GL_DEPTH_TEST);
			glEnable(GL_CULL_FACE);

			foreach (m; m_models) {
				Matrix transform = m.getMatrix();
				
				glPushMatrix();
				glMultMatrixf(transform.data.ptr);
				
				glVertexPointer(3, GL_FLOAT, 0, m.vertexes.ptr);
				glDrawArrays(GL_TRIANGLES, 0, m.triangleCount * 3);
				
				glPopMatrix();
			}
			
			glDisable(GL_DEPTH_TEST);
			glDisable(GL_CULL_FACE);
		break;
		case CameraStyle.COLORS:
			glEnableClientState(GL_VERTEX_ARRAY);
			scope (exit) glDisableClientState(GL_VERTEX_ARRAY);
			glEnableClientState(GL_COLOR_ARRAY);
			scope (exit) glDisableClientState(GL_COLOR_ARRAY);
			
			glEnable(GL_DEPTH_TEST);
			glEnable(GL_CULL_FACE);

			foreach (m; m_models) {
				Matrix transform = m.getMatrix();
				
				glPushMatrix();
				glMultMatrixf(transform.data.ptr);
				
				glVertexPointer(3, GL_FLOAT, 0, m.vertexes.ptr);
				glColorPointer(3, GL_FLOAT, 0, m.colors.ptr);
				glDrawArrays(GL_TRIANGLES, 0, m.triangleCount * 3);
				
				glPopMatrix();
			}
			
			glDisable(GL_DEPTH_TEST);
			glDisable(GL_CULL_FACE);
		break;
		case CameraStyle.LIGHTING:
			glEnableClientState(GL_VERTEX_ARRAY);
			scope (exit) glDisableClientState(GL_VERTEX_ARRAY);
			glEnableClientState(GL_NORMAL_ARRAY);
			scope (exit) glDisableClientState(GL_NORMAL_ARRAY);
			
			glShadeModel(GL_SMOOTH);
			glMaterialfv(GL_FRONT, GL_SPECULAR, white.data.ptr);
			glMaterialfv(GL_FRONT, GL_SHININESS, lightingShininess.ptr);
			glLightModelfv(GL_LIGHT_MODEL_AMBIENT, ambientLight.data.ptr);
			
			glEnable(GL_DEPTH_TEST);
			glEnable(GL_CULL_FACE);
			glEnable(GL_LIGHTING);
			
			GLenum lNum = GL_LIGHT0;
			foreach (l; m_lights) {
				glEnable(lNum);
				
				switch (l.type) {
				case LightType.AMBIENT:
					glLightfv(lNum, GL_AMBIENT, l.ambientColor.data.ptr);
				break;
				case LightType.DIFFUSE:
					float[4] pos;
					pos[0..3] = l.position.data[0..3];
					
					glLightfv(lNum, GL_AMBIENT, l.ambientColor.data.ptr);
					glLightfv(lNum, GL_DIFFUSE, l.diffuseColor.data.ptr);
					glLightfv(lNum, GL_POSITION, pos.ptr);
				break;
				}
				++lNum;
			}

			foreach (m; m_models) {
				Matrix transform = m.getMatrix();
				
				glPushMatrix();
				glMultMatrixf(transform.data.ptr);
				
				glVertexPointer(3, GL_FLOAT, 0, m.vertexes.ptr);
				glNormalPointer(GL_FLOAT, 0, m.normals.ptr);
				glDrawArrays(GL_TRIANGLES, 0, m.triangleCount * 3);
				
				glPopMatrix();
			}
			
			for (; lNum >= GL_LIGHT0; lNum--) {
				glDisable(lNum);
			}
			
			glDisable(GL_DEPTH_TEST);
			glDisable(GL_CULL_FACE);
			glDisable(GL_LIGHTING);
		break;
		case (CameraStyle.COLORS | CameraStyle.LIGHTING):
			glEnableClientState(GL_VERTEX_ARRAY);
			scope (exit) glDisableClientState(GL_VERTEX_ARRAY);
			glEnableClientState(GL_COLOR_ARRAY);
			scope (exit) glDisableClientState(GL_COLOR_ARRAY);
			glEnableClientState(GL_NORMAL_ARRAY);
			scope (exit) glDisableClientState(GL_NORMAL_ARRAY);
			
/*			GLenum lNum = GL_LIGHT0;
			foreach (l; m_lights) {
				switch (l.type) {
				case LightType.AMBIENT:
//					glLightfv(lNum, GL_AMBIENT, l.ambientColor.data.ptr);
				break;
				case LightType.DIFFUSE:
					float[4] pos;
					pos[0..3] = l.position.data[0..3];
					
					glLightfv(lNum, GL_AMBIENT, black.data.ptr);
					glLightfv(lNum, GL_SPECULAR, white.data.ptr);
					glLightfv(lNum, GL_DIFFUSE, white.data.ptr);
					glLightfv(lNum, GL_POSITION, pos.ptr);
				break;
				}
				glEnable(lNum);
				++lNum;
			}
			glEnable(GL_LIGHTING);
			glLightModelfv(GL_LIGHT_MODEL_AMBIENT, ambientLight.data.ptr);
			
			glShadeModel(GL_SMOOTH);
			glEnable(GL_COLOR_MATERIAL);
			glColorMaterial(GL_FRONT, GL_AMBIENT_AND_DIFFUSE);
			glMaterialfv(GL_FRONT, GL_SPECULAR, white.data.ptr);
			glMaterialfv(GL_FRONT, GL_EMISSION, black.data.ptr);
*/
float[4] pos = [10.0f, 10.0f, 10.0f, 0.0f];
glLightfv(GL_LIGHT0, GL_POSITION, pos.ptr);

glEnable(GL_LIGHT0);
glEnable(GL_LIGHTING);
glEnable(GL_COLOR_MATERIAL);
			
			glEnable(GL_DEPTH_TEST);
			glEnable(GL_CULL_FACE);

			foreach (m; m_models) {
				Matrix transform = m.getMatrix();
				
				glPushMatrix();
				glMultMatrixf(transform.data.ptr);
				
				glVertexPointer(3, GL_FLOAT, 0, m.vertexes.ptr);
				glColorPointer(3, GL_FLOAT, 0, m.colors.ptr);
				glNormalPointer(GL_FLOAT, 0, m.normals.ptr);
				glDrawArrays(GL_TRIANGLES, 0, m.triangleCount * 3);
				
				glPopMatrix();
			}
			
//			for (; lNum >= GL_LIGHT0; lNum--) {
//				glDisable(lNum);
//			}
			
glDisable(GL_COLOR_MATERIAL);
			glDisable(GL_DEPTH_TEST);
			glDisable(GL_CULL_FACE);
glDisable(GL_LIGHTING);
glDisable(GL_LIGHT0);
		break;
		}
	}
}

class QCamera : Camera {
public:
}

class ECamera : Camera {
public:
	mixin VPositioned;
	mixin ERotated;
	
	Matrix getMatrix() {
		Matrix ret = rotation.getMatrix();
		ret.setTranslation(position);
		ret = ret.getInverse();
		
		return ret;
	}
}
