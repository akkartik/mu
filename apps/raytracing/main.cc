#include <iostream>

// print float in some sort of intuitive hex that also helps visualize the underlying bits
void p(std::ostream &out, float f) {
    int bits = *(int*)&f;
    // sign
    if (bits & 0x80000000) {
      out << '-';
    }
    // mantissa
    int mantissa = bits & 0x007fffff;
    int exponent = (bits & 0x7f800000) >> 23;
    out << std::hex << mantissa << "P" << std::dec << (exponent-127);
}

#include "color.h"
#include "ray.h"
#include "vec3.h"

color ray_color(const ray& r) {
//?     std::cerr << "r.dir: " << r.direction() << '\n';
//?     std::cerr << "r.dir length: ";
//?       p(std::cerr, r.direction().length());
//?       std::cerr << '\n';
    vec3 unit_direction = unit_vector(r.direction());
//?     std::cerr << "r.dir normalized: " << unit_direction << '\n';
    float t = 0.5*(unit_direction.y() + 1.0);
//?     std::cerr << "t: ";
//?       p(std::cerr, t);
//?       std::cerr << '\n';
    vec3 whitening = (1.0-t)*color(1.0, 1.0, 1.0);
//?     std::cerr << "whitening: ";
//?       p(std::cerr, whitening.x());
//?       std::cerr << " ";
//?       p(std::cerr, whitening.y());
//?       std::cerr << " ";
//?       p(std::cerr, whitening.z());
//?       std::cerr << "\n";
    vec3 base = t*color(0.5, 0.7, 1.0);
//?     std::cerr << "base: ";
//?       p(std::cerr, base.x());
//?       std::cerr << " ";
//?       p(std::cerr, base.y());
//?       std::cerr << " ";
//?       p(std::cerr, base.z());
//?       std::cerr << "\n";
    vec3 result = base + whitening;
//?     std::cerr << "result: ";
//?       p(std::cerr, result.x());
//?       std::cerr << " ";
//?       p(std::cerr, result.y());
//?       std::cerr << " ";
//?       p(std::cerr, result.z());
//?       std::cerr << "\n";
    return result;
}

int main() {

    // Image
    const float aspect_ratio = 16.0 / 9.0;
//?     std::cerr << "aspect ratio: " << aspect_ratio << ' ' << std::hex << *(int*)&aspect_ratio << '\n';
    const int image_width = 400;
    const int image_height = static_cast<int>(image_width / aspect_ratio);

    // Camera

    float viewport_height = 2.0;
//?     std::cerr << "viewport height: " << viewport_height << ' ' << std::hex << *(int*)&viewport_height << '\n';
    float viewport_width = aspect_ratio * viewport_height;
//?     std::cerr << "viewport width: " << viewport_width << ' ' << std::hex << *(int*)&viewport_width << '\n';
    float focal_length = 1.0;

    auto origin = point3(0, 0, 0);
    auto horizontal = vec3(viewport_width, 0, 0);
    auto vertical = vec3(0, viewport_height, 0);
    auto lower_left_corner = origin - horizontal/2 - vertical/2 - vec3(0, 0, focal_length);

    // Render

    std::cout << "P3\n" << image_width << " " << image_height << "\n255\n";

    for (int j = image_height-1; j >= 0; --j) {
//?         std::cerr << "\rScanlines remaining: " << j << ' ' << std::flush;
        for (int i = 0; i < image_width; ++i) {
            auto u = float(i) / (image_width-1);
//?             std::cerr << "u: " << u << '\n';
            auto v = float(j) / (image_height-1);
            ray r(origin, lower_left_corner + u*horizontal + v*vertical - origin);
//?             std::cerr << "ray origin: " << r.orig.x() << " " << r.orig.y() << " " << r.orig.z() << '\n';
//?             std::cerr << "ray direction: " << r.dir.x() << " " << r.dir.y() << " " << r.dir.z() << '\n';
//?             std::cerr << "ray dir.x: " << r.dir.x() << " ";
//?               p(std::cerr, r.dir.x());
//?               std::cerr << '\n';
            color pixel_color = ray_color(r);
//?             std::cerr << "pixel color: " << pixel_color.x() << " " << pixel_color.y() << " " << pixel_color.z() << '\n';

//?             std::cout << "(";
//?               p(std::cout, pixel_color.x());
//?               std::cout << ", ";
//?               p(std::cout, pixel_color.y());
//?               std::cout << ", ";
//?               p(std::cout, pixel_color.z());
//?               std::cout << ")\n";
            write_color(std::cout, pixel_color);
//?             break;
        }
//?         break;
    }

//?     std::cerr << "\r";
}
