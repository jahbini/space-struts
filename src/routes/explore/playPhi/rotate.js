export function rotatePointAroundLine(P1, P2, P3, theta) {
    /**
     * Rotates point P3 around the line defined by points P1 and P2 by angle theta.
     *
     * @param {Array} P1 - 3D coordinates of the first point on the line [x1, y1, z1].
     * @param {Array} P2 - 3D coordinates of the second point on the line [x2, y2, z2].
     * @param {Array} P3 - 3D coordinates of the point to rotate [x3, y3, z3].
     * @param {Number} theta - Angle of rotation in radians.
     * @returns {Array} - Rotated point P3 as an array [x', y', z'].
     */
    // Helper functions
    const dot = (a, b) => a.reduce((sum, ai, i) => sum + ai * b[i], 0);
    const subtract = (a, b) => a.map((ai, i) => ai - b[i]);
    const add = (a, b) => a.map((ai, i) => ai + b[i]);
    const scale = (a, s) => a.map(ai => ai * s);
    const cross = (a, b) => [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0]
    ];

    // Convert to vectors
    const lineVec = subtract(P2, P1);
    const lineLength = Math.sqrt(dot(lineVec, lineVec));
    const unitLineVec = scale(lineVec, 1 / lineLength);

    // Translate P3 to the origin relative to P1
    const P3Rel = subtract(P3, P1);

    // Rodrigues' rotation formula components
    const cosTheta = Math.cos(theta);
    const sinTheta = Math.sin(theta);
    const u = unitLineVec;
    const dotProduct = dot(u, P3Rel);
    const crossProduct = cross(u, P3Rel);

    // Rodrigues' rotation formula
    const rotatedRel = add(
        add(scale(P3Rel, cosTheta), scale(crossProduct, sinTheta)),
        scale(u, dotProduct * (1 - cosTheta))
    );

    // Translate back to original position
    const rotated = add(rotatedRel, P1);
    return rotated;
}

// Example Usage
const P1 = [0, 0, 0];
const P2 = [0, 0, 1];
const P3 = [1, 0, 0];
const theta = Math.PI / 4; // 45 degrees in radians

const rotatedPoint = rotatePointAroundLine(P1, P2, P3, theta);
console.log("Rotated Point:", rotatedPoint);
/**
 * Compute the reflection of a point across a plane.
 * @param {Array} point - The point to reflect [x, y, z].
 * @param {Array} planeVertices - Three vertices defining the plane [[x1, y1, z1], [x2, y2, z2], [x3, y3, z3]].
 * @returns {Array} Reflected point [x', y', z'].
 */
export function reflectPointAcrossPlane(point, planeVertices) {
    const [v1, v2, v3] = planeVertices;

    // Compute two vectors on the plane
    const vec1 = [v2[0] - v1[0], v2[1] - v1[1], v2[2] - v1[2]];
    const vec2 = [v3[0] - v1[0], v3[1] - v1[1], v3[2] - v1[2]];

    // Compute the normal vector of the plane
    const normal = [
        vec1[1] * vec2[2] - vec1[2] * vec2[1],
        vec1[2] * vec2[0] - vec1[0] * vec2[2],
        vec1[0] * vec2[1] - vec1[1] * vec2[0]
    ];

    // Normalize the normal vector
    const normalLength = Math.sqrt(normal[0]**2 + normal[1]**2 + normal[2]**2);
    const unitNormal = normal.map((n) => n / normalLength);

    // Compute the vector from the point to a point on the plane
    const pointToPlane = [point[0] - v1[0], point[1] - v1[1], point[2] - v1[2]];

    // Project the point onto the normal vector
    const distance = pointToPlane[0] * unitNormal[0] +
                     pointToPlane[1] * unitNormal[1] +
                     pointToPlane[2] * unitNormal[2];

    // Compute the reflected point
    const reflectedPoint = [
        point[0] - 2 * distance * unitNormal[0],
        point[1] - 2 * distance * unitNormal[1],
        point[2] - 2 * distance * unitNormal[2]
    ];

    return reflectedPoint;
}

// Example usage
const reflectionPoint = [0, -1, 1.61803399]; // A vertex of the dodecahedron
export const planeVertices = [
    [0, 1, 1.61803399], 
    [-1.61803399, 0, 1], 
    [1.61803399, 0, 1]
]; // Plane defined by a face of the dodecahedron

const point = reflectPointAcrossPlane(reflectionPoint, planeVertices);
console.log("Reflected Point:", point);
