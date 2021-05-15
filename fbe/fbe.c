#include <SDL2/SDL.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

int main(int argc, char ** argv) {
    int fd = open("/tmp/fb0", O_RDWR);
    uint32_t *pixels = mmap(0, 1024*768*4, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);

    SDL_Event event;
    SDL_SetHint (SDL_HINT_RENDER_SCALE_QUALITY, "2");
    SDL_Init(SDL_INIT_VIDEO);
    SDL_Window *window = SDL_CreateWindow("fbe", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1024, 768, 0);
    SDL_Renderer *renderer = SDL_CreateRenderer(window, -1, 0);
    SDL_Texture *texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STATIC, 1024, 768);
    int quit = 0;
    while (!quit) {
        SDL_UpdateTexture(texture, NULL, pixels, 1024*4);
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
        usleep(10000);

        while (SDL_PollEvent(&event)) {
            switch (event.type) {
                case SDL_QUIT:
                    quit = 1;
                    break;
            }
        }
    }
    SDL_DestroyWindow(window);
    SDL_Quit();
}
