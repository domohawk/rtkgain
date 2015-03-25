#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "src/rtkfil.h"

#define MTR_URI "http://github.com/domohawk/lv2/rtkfil#"
#define MTR_GUI "rtkfil"

#define LVGL_RESIZEABLE

typedef struct {
    RobWidget* frame;
    RobWidget* rw;
    RobWidget* w_tbl;
    LV2UI_Write_Function write;
    LV2UI_Controller     controller;
    RobTkSpin* spn_gain;
    RobTkLbl* lbl_gain;
    cairo_surface_t* dial[1];
    //bool initialized;
    float c_txt[4];
    float gain;
} FILGUI;


/******************************************************************************
 * Drawing helpers
 */
//static void write_text(
//        cairo_t* cr,
//        const char *txt, const char * font,
//        const float x, const float y,
//        const int align,
//        const float * const col) {
//    PangoFontDescription *fd;
//    if (font) {
//        fd = pango_font_description_from_string(font);
//    } else {
//        fd = get_font_from_theme();
//    }
//    write_text_full(cr, txt, fd, x, y, 0, align, col);
//    pango_font_description_free(fd);
//static void alloc_annotations(FILGUI* ui) {
//#define FONT_LB "Sans 06"
//    cairo_t* cr;
//#define INIT_DIAL_SF(VAR, TXTL, TXTR) \
//    VAR = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, GED_WIDTH, GED_HEIGHT); \
//    cr = cairo_create (VAR); \
//    CairoSetSouerceRGBA(c_trs); \
//    cairo_set_operator (cr, CAIRO_OPERATOR_SOURCE); \
//    cairo_set_operator (cr, CAIRO_OPERATOR_SOURCE); \
//    cairo_rectangle (cr, 0, 0, GED_WIDTH, GED_HEIGHT); \
//    cairo_fill (cr); \
//    cairo_set_operator (cr, CAIRO_OPERATOR_OVER); \
//    write_text(cr, TXTL, FONT_LB, 2, GED_HEIGHT - 1, 6, ui->c_txt); \
//    write_text(cr, TXTR, FONT_LB, GED_WIDTH-1, GED_HEIGHT - 1, 4, ui->c_txt); \
//    cairo_destroy (cr);
//    INIT_DIAL_SF(ui->dial[0], "0db", "+6db")
//}

/******************************************************************************
 * Main drawing function
 */
static bool expose_event(RobWidget* handle, cairo_t* cr, cairo_rectangle_t* ev) {
    fprintf(stderr, "enter expose_event!\n");
    FILGUI* ui = (FILGUI*)GET_HANDLE(handle);
    cairo_rectangle(cr, ev->x, ev->y, ev->width, ev->height);
    cairo_clip(cr);
    fprintf(stderr, "exit expose_event!\n");
    return TRUE;
}
static void size_request(RobWidget* handle, int *w, int *h) {
    FILGUI* ui = (FILGUI*)GET_HANDLE(handle);
    robwidget_set_size(ui->rw, 200, 200);
    *w = 200;
    *h = 200;
}


/******************************************************************************
 * Child callbacks
 */
static bool cb_gain(RobWidget *w, gpointer handle) {
    FILGUI* ui = (FILGUI*)handle;
    float val = robtk_spin_get_value(ui->spn_gain);
//    if (v < 0) {
//        robtk_spin_set_value(ui->spn_gain, 0.0);
//        return TRUE;
//    }
//    if (v > 2) {
//        robtk_spin_set_value(ui->spn_gain, 2.0);
//        return TRUE;
//    }
    // TODO share index with header
    ui->write(ui->controller, RTKFIL_GAIN, sizeof(float), 0, (const void*) &val);
    //save_state(ui);
    return TRUE;
}


/******************************************************************************
 * LV2 callbacks
 */
static void ui_enable(LV2UI_Handle handle) { }
static void ui_disable(LV2UI_Handle handle) { }

static LV2UI_Handle
instantiate(void* const               ui_toplevel,
            const LV2UI_Descriptor*   descriptor,
            const char*               plugin_uri,
            const char*               bundle_path,
            LV2UI_Write_Function      write_function,
            LV2UI_Controller          controller,
            RobWidget**               widget,
            const LV2_Feature* const* features) {
    FILGUI* ui = (FILGUI*) calloc(1, sizeof(FILGUI));
    *widget = NULL;

    if (!ui) {
        fprintf (stderr, "rtkfil.lv2: out of memory.\n");
        return NULL;
    }

    if(strcmp(plugin_uri, MTR_URI "rtkfil")) {
        free(ui);
        fprintf(stderr, "invalid uri: %s : %s\n", plugin_uri, MTR_URI);
        return NULL;
    }

    ui->write = write_function;
    ui->controller = controller;

    ui->frame = rob_vbox_new(FALSE, 2);
    robwidget_make_toplevel(ui->frame, ui_toplevel);
    ROBWIDGET_SETNAME(ui->frame, "gtkfil");

    ui->rw = robwidget_new(ui);
    robwidget_set_expose_event(ui->rw, expose_event);
    robwidget_set_size_request(ui->rw, size_request);
    //robwidget_set_mousedown(ui->rw, mousedown);
    //robwidget_set_mouseup(ui->rw, mouseup);

    ui->w_tbl = rob_table_new(1, 1, FALSE);
    ui->spn_gain = robtk_spin_new(0.0, 2.0, 0.1);
    robtk_spin_set_default(ui->spn_gain, 1.0);
    robtk_spin_set_value(ui->spn_gain, 1.0);
    //robtk_spin_set_alignment(ui->spn_gain, 0.0, 0.5);
    robtk_spin_label_width(ui->spn_gain,    12.0, 32);
    robtk_spin_set_callback(ui->spn_gain, cb_gain, ui);
    // TODO clean this up
    cb_gain(NULL, ui);

    // Layout
    rob_table_attach_defaults(ui->w_tbl, robtk_spin_widget(ui->spn_gain), 0, 1, 0 ,1);
    rob_vbox_child_pack(ui->frame, ui->rw, FALSE, TRUE);
    rob_vbox_child_pack(ui->frame, ui->w_tbl, TRUE, TRUE);

    *widget = ui->frame;

    fprintf(stderr, "exit instantiate!\n");
    return ui;
}

static enum LVGLResize
plugin_scale_mode(LV2UI_Handle handle) {
    return LVGL_LAYOUT_TO_FIT;
}

static void
cleanup(LV2UI_Handle handle) {
    FILGUI* ui = (FILGUI*)handle;
    robtk_spin_destroy(ui->spn_gain);
    robwidget_destroy(ui->rw);
    rob_table_destroy(ui->w_tbl);
    rob_box_destroy(ui->frame);
}

static const void*
extension_data(const char* uri) {
    return NULL;
}


/******************************************************************************
 * Backend communication
 */
static void
invalidate_area(LV2UI_Handle* ui, int c, float oldval, float newval) {
    // TODO
}

static void
port_event(LV2UI_Handle handle,
           uint32_t     port_index,
           uint32_t     buffer_size,
           uint32_t     format,
           const void*  buffer) {
    // TODO
}
