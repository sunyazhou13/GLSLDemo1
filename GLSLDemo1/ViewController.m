//
//  ViewController.m
//  GLSLDemo1
//
//  Created by sunyazhou on 2019/4/11.
//  Copyright © 2019 sunyazhou.com. All rights reserved.
//

#import "ViewController.h"
#import <GLKit/GLKit.h>

//顶点结构体类型
typedef struct {
    GLKVector3 positionCoord; // (x,y,z)
    GLKMatrix2 textureCoord; // (u, v)
    
} SenceVertex;


@interface ViewController ()

@property (nonatomic, assign) SenceVertex *vertices; //顶点数组
@property (nonatomic, strong) EAGLContext *context;

@end

@implementation ViewController

#pragma mark -
#pragma mark - override methods 复写方法
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self commonInit];
}

#pragma mark -
#pragma mark - private methods 私有方法
- (void)commonInit {
    // 创建上下文 使用 2.0版本
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.context];
    
    //创建顶点数组
    self.vertices = malloc(sizeof(SenceVertex) * 4); //4个顶点
    
    self.vertices[0] = (SenceVertex){{-1, 1, 0},{ 0, 1 }}; //左上角
    self.vertices[1] = (SenceVertex){{-1, -1, 0},{0 ,0}}; //左下角
    self.vertices[2] = (SenceVertex){{1, 1, 0},{1, 1}}; //右上角
    self.vertices[3] = (SenceVertex){{1, -1, 0},{1, 0}}; //右下角
    
    //创建一个展示纹理的layer
    
    CAEAGLLayer *layer = [CAEAGLLayer layer];
    layer.frame = CGRectMake(0, 100, self.view.frame.size.width, self.view.frame.size.width);
    layer.contentsScale = [[UIScreen mainScreen] scale]; //设置缩放比例，不设置的话，纹理会失真
    
    [self.view.layer addSublayer:layer];
    
    // 绑定纹理到输出layer
    [self bindRenderLayer:layer];
    
    // 读取纹理
    NSString *imagePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"logo.png"];
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    GLuint textureID = [self createTextureWithImage:image];
    
    
    // 设置视口尺寸
    
    glViewport(0, 0, self.drawableWidth, self.drawableHeight);
    
    // 编译链接 着色器
    GLuint program = [self programWithShaderName:@"glsl"];
    glUseProgram(program);
    
    // 获取shader 中的参数 然后传数据进去
    GLuint positionSlot = glGetAttribLocation(program, "Position"); //获取顶点着色器的位置
    GLuint textureCoordsSlot = glGetAttribLocation(program, "TextureCoords"); //获取顶点着色器中的纹理坐标

    GLuint textureSlot = glGetUniformLocation(program, "Texture"); //获取片元着色器纹理变量

    //将纹理 ID 传给着色器程序
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, textureID);
    glUniform1i(textureSlot, 0); // 将textureSlot 赋值为 0, 而 0 与 GL_TEXTURE0 对应,这里如果写1,就是GL_TEXTURE1
    
    // 创建顶点缓存
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(SenceVertex) * 4;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices, GL_STATIC_DRAW);
    
    // 设置顶点数据
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, positionCoord));
    
    // 设置纹理数据
    glEnableVertexAttribArray(textureCoordsSlot);
    glVertexAttribPointer(textureCoordsSlot, 2, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, textureCoord));
    
    // 开始绘制
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    // 将绑定
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
    
    //删除顶点缓存
    glDeleteBuffers(1, &vertexBuffer);
    vertexBuffer = 0;
    
}

//绑定图像要输出的 layer
- (void)bindRenderLayer:(CALayer <EAGLDrawable> *)layer {
    GLuint frameBuffer; //帧缓冲
    GLuint renderBuffer; //渲染缓冲

    //绑定渲染缓冲到 输出的layer
    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    
    //将渲染缓冲附着在帧缓冲上
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuffer);
}

// 通过一个图片 创建纹理
- (GLuint)createTextureWithImage:(UIImage *)image {
    // 将 UIImage 转换为 CGImageRef
    CGImageRef cgImageRef = [image CGImage];
    GLuint width = (GLuint)CGImageGetWidth(cgImageRef);
    GLuint height = (GLuint)CGImageGetHeight(cgImageRef);
    CGRect rect = CGRectMake(0, 0, width, height);
    
    // 绘制图片
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    void *imageData = malloc(width * height * 4);
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGColorSpaceRelease(colorSpace);
    CGContextClearRect(context, rect);
    CGContextDrawImage(context, rect, cgImageRef);

    // 生成纹理
    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData); // 将图片数据写入纹理缓存
    
    // 设置如何把纹素映射成像素
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    // 解绑
    glBindTexture(GL_TEXTURE_2D, 0);
    
    // 释放内存
    CGContextRelease(context);
    free(imageData);
    
    return textureID;
}

// 将一个顶点着色器和片元着色器挂在到一个着色器程序上, 并返回程序的 id
- (GLuint)programWithShaderName:(NSString *)shaderName {
    // 编译两个着色器
    GLuint vertexShader = [self compileShaderWithName:shaderName type:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShaderWithName:shaderName type:GL_FRAGMENT_SHADER];
    
    // 挂载 shader 到 program 上
    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    
    // 链接 program
    glLinkProgram(program);
    
    // 检查链接是否成功
    GLint linkSuccess;
    glGetProgramiv(program, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(program, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"program链接失败：%@", messageString);
        exit(1);
    }
    return program;
}

// 编译一个 shader，并返回 shader 的 id
- (GLuint)compileShaderWithName:(NSString *)name type:(GLenum)shaderType {
    // 查找 shader 文件
    NSString *shaderPath = [[NSBundle mainBundle] pathForResource:name ofType:shaderType == GL_VERTEX_SHADER ? @"vsh" : @"fsh"]; // 根据不同的类型确定后缀名
    NSError *error;
    NSString *shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSAssert(NO, @"读取shader失败");
        exit(1);
    }
    
    // 创建一个 shader 对象
    GLuint shader = glCreateShader(shaderType);
    
    // 获取 shader 的内容
    const char *shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    glShaderSource(shader, 1, &shaderStringUTF8, &shaderStringLength);
    
    // 编译shader
    glCompileShader(shader);
    
    // 查询 shader 是否编译成功
    GLint compileSuccess;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shader, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"shader编译失败：%@", messageString);
        exit(1);
    }
    
    return shader;
}


#pragma mark -
#pragma mark - public methods 公有方法



#pragma mark -
#pragma mark - getters and setters 设置器和访问器
// 获取渲染缓存宽度
- (GLint)drawableWidth {
    GLint backingWidth;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    
    return backingWidth;
}

// 获取渲染缓存高度
- (GLint)drawableHeight {
    GLint backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    return backingHeight;
}




#pragma mark -
#pragma mark - UITableViewDelegate
#pragma mark -
#pragma mark - CustomDelegate 自定义的代理
#pragma mark -
#pragma mark - event response 所有触发的事件响应 按钮、通知、分段控件等
#pragma mark -
#pragma mark - life cycle 视图的生命周期
- (void)dealloc {
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    //释放结构体内存的数组 需要手动free
    if (_vertices) {
        free(_vertices);
        _vertices = nil;
    }
}

#pragma mark -
#pragma mark - StatisticsLog 各种页面统计Log




@end
