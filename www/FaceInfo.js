var FaceInfo = function(left, top, right, bottom,
                    leftEyeX, leftEyeY, rightEyeX, rightEyeY,
                    mouthX, mouthY) {
    this.left = left;
    this.top = top;
    this.right = right;
    this.bottom = bottom;

    if (leftEyeX && leftEyeX >= 0 && leftEyeY && leftEyeY >= 0) {
        this.leftEye = {x: leftEyeX, y: leftEyeY};
    }
    if (rightEyeX && rightEyeX >= 0 && rightEyeY && rightEyeY >= 0) {
        this.rightEye = {x: rightEyeX, y: rightEyeY};
    }
    if (mouthX && mouthX >= 0 && mouthY && mouthY >= 0) {
        this.rightEye = {x: mouthX, y: mouthY};
    }
};

module.exports = FaceInfo;