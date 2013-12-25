module lfds611;

extern(C) {
    /***** library header *****/
    enum LFDS611_RELEASE_NUMBER_STRING = "6.1.1";

    /***** lfds611_abstraction *****/
    alias ulong lfds611_atom_t;

    /***** enums *****/
    enum lfds611_data_structure_validity {
        LFDS611_VALIDITY_VALID,
                LFDS611_VALIDITY_INVALID_LOOP,
                LFDS611_VALIDITY_INVALID_MISSING_ELEMENTS,
                LFDS611_VALIDITY_INVALID_ADDITIONAL_ELEMENTS,
                LFDS611_VALIDITY_INVALID_TEST_DATA
                };

    /***** structs *****/
    struct lfds611_validation_info {
        lfds611_atom_t min_elements, max_elements;
    };

    /***** public prototypes *****/
    void *lfds611_abstraction_malloc( size_t size );
    void lfds611_abstraction_free( void *memory );


    /***** lfds611_freelist *****/

    /***** enums *****/
    enum lfds611_freelist_query_type {
        LFDS611_FREELIST_QUERY_ELEMENT_COUNT,
                LFDS611_FREELIST_QUERY_VALIDATE
                };

    /***** incomplete types *****/
    struct lfds611_freelist_state;
    struct lfds611_freelist_element;

    /***** public prototypes *****/
    int lfds611_freelist_new( shared lfds611_freelist_state **fs, lfds611_atom_t number_elements, int function(void **user_data, void *user_state) user_data_init_function, void *user_state );
    void lfds611_freelist_use( shared lfds611_freelist_state *fs );
    void lfds611_freelist_delete( shared lfds611_freelist_state *fs, void function(void *user_data, void *user_state) user_data_delete_function, void *user_state );

    lfds611_atom_t lfds611_freelist_new_elements( shared lfds611_freelist_state *fs, lfds611_atom_t number_elements );

    lfds611_freelist_element *lfds611_freelist_pop( shared lfds611_freelist_state *fs, lfds611_freelist_element **fe );
    lfds611_freelist_element *lfds611_freelist_guaranteed_pop( shared lfds611_freelist_state *fs, lfds611_freelist_element **fe );
    void lfds611_freelist_push( shared lfds611_freelist_state *fs, lfds611_freelist_element *fe );

    void *lfds611_freelist_get_user_data_from_element( shared lfds611_freelist_element *fe, void **user_data );
    void lfds611_freelist_set_user_data_in_element( shared lfds611_freelist_element *fe, void *user_data );

    void lfds611_freelist_query( shared lfds611_freelist_state *fs, lfds611_freelist_query_type query_type, void *query_input, void *query_output );

    /***** lfds611_liblfds *****/
    /***** public prototypes *****/
    void lfds611_liblfds_abstraction_test_helper_increment_non_atomic( shared lfds611_atom_t *shared_counter );
    void lfds611_liblfds_abstraction_test_helper_increment_atomic( shared lfds611_atom_t *shared_counter );
    void lfds611_liblfds_abstraction_test_helper_cas( shared lfds611_atom_t *shared_counter, lfds611_atom_t *local_counter );
    void lfds611_liblfds_abstraction_test_helper_dcas( shared lfds611_atom_t *shared_counter, lfds611_atom_t *local_counter );

    /***** lfds611_queue *****/
    /***** enums *****/
    enum lfds611_queue_query_type {
        LFDS611_QUEUE_QUERY_ELEMENT_COUNT,
                LFDS611_QUEUE_QUERY_VALIDATE
                };

    /***** incomplete types *****/
    struct lfds611_queue_state;

    /***** public prototypes *****/
    int lfds611_queue_new( shared lfds611_queue_state **sq, lfds611_atom_t number_elements );
    void lfds611_queue_use( shared lfds611_queue_state *qs );
    void lfds611_queue_delete( shared lfds611_queue_state *qs, void function(void *user_data, void *user_state) user_data_delete_function, void *user_state );

    int lfds611_queue_enqueue( shared lfds611_queue_state *qs, void *user_data );
    int lfds611_queue_guaranteed_enqueue( shared lfds611_queue_state *qs, void *user_data );
    int lfds611_queue_dequeue( shared lfds611_queue_state *qs, void **user_data );

    void lfds611_queue_query( shared lfds611_queue_state *qs, lfds611_queue_query_type query_type, void *query_input, void *query_output );

    /***** lfds611_ringbuffer *****/
    /***** enums *****/
    enum lfds611_ringbuffer_query_type {
        LFDS611_RINGBUFFER_QUERY_VALIDATE
                };

    /***** incomplete types *****/
    struct lfds611_ringbuffer_state;

    /***** public prototypes *****/
    int lfds611_ringbuffer_new( shared lfds611_ringbuffer_state **rs, lfds611_atom_t number_elements, int function(void **user_data, void *user_state) user_data_init_function, void *user_state );
    void lfds611_ringbuffer_use( shared lfds611_ringbuffer_state *rs );
    void lfds611_ringbuffer_delete( shared lfds611_ringbuffer_state *rs, void function(void *user_data, void *user_state) user_data_delete_function, void *user_state );

    lfds611_freelist_element *lfds611_ringbuffer_get_read_element( shared lfds611_ringbuffer_state *rs, lfds611_freelist_element **fe );
    lfds611_freelist_element *lfds611_ringbuffer_get_write_element( shared lfds611_ringbuffer_state *rs, lfds611_freelist_element **fe, int *overwrite_flag );

    void lfds611_ringbuffer_put_read_element( shared lfds611_ringbuffer_state *rs, lfds611_freelist_element *fe );
    void lfds611_ringbuffer_put_write_element( shared lfds611_ringbuffer_state *rs, lfds611_freelist_element *fe );

    void lfds611_ringbuffer_query( shared lfds611_ringbuffer_state *rs, lfds611_ringbuffer_query_type query_type, void *query_input, void *query_output );

    /***** lfds611_slist *****/
    /***** incomplete types *****/
    struct lfds611_slist_state;
    struct lfds611_slist_element;

    /***** public prototypes *****/
    int lfds611_slist_new( shared lfds611_slist_state **ss, void function(void *user_data, void *user_state) user_data_delete_function, void *user_state );
    void lfds611_slist_use( shared lfds611_slist_state *ss );
    void lfds611_slist_delete( shared lfds611_slist_state *ss );

    lfds611_slist_element *lfds611_slist_new_head( shared lfds611_slist_state *ss, void *user_data );
    lfds611_slist_element *lfds611_slist_new_next( shared lfds611_slist_element *se, void *user_data );

    int lfds611_slist_logically_delete_element( shared lfds611_slist_state *ss, lfds611_slist_element *se );
    void lfds611_slist_single_threaded_physically_delete_all_elements( shared lfds611_slist_state *ss );

    int lfds611_slist_get_user_data_from_element( shared lfds611_slist_element *se, void **user_data );
    int lfds611_slist_set_user_data_in_element( shared lfds611_slist_element *se, void *user_data );

    lfds611_slist_element *lfds611_slist_get_head( shared lfds611_slist_state *ss, lfds611_slist_element **se );
    lfds611_slist_element *lfds611_slist_get_next( shared lfds611_slist_element *se, lfds611_slist_element **next_se );
    lfds611_slist_element *lfds611_slist_get_head_and_then_next( shared lfds611_slist_state *ss, lfds611_slist_element **se );

    /***** lfds611_stack *****/
    /***** enums *****/
    enum lfds611_stack_query_type {
        LFDS611_STACK_QUERY_ELEMENT_COUNT,
                LFDS611_STACK_QUERY_VALIDATE
                };

    /***** incomplete types *****/
    struct lfds611_stack_state;

    /***** public prototypes *****/
    int lfds611_stack_new( shared lfds611_stack_state **ss, lfds611_atom_t number_elements );
    void lfds611_stack_use( shared lfds611_stack_state *ss );
    void lfds611_stack_delete( shared lfds611_stack_state *ss, void function(void *user_data, void *user_state) user_data_delete_function, void *user_state );

    void lfds611_stack_clear( shared lfds611_stack_state *ss, void function(void *user_data, void *user_state) user_data_clear_function, void *user_state );

    int lfds611_stack_push( shared lfds611_stack_state *ss, void *user_data );
    int lfds611_stack_guaranteed_push( shared lfds611_stack_state *ss, void *user_data );
    int lfds611_stack_pop( shared lfds611_stack_state *ss, void **user_data );

    void lfds611_stack_query( shared lfds611_stack_state *ss, lfds611_stack_query_type query_type, void *query_input, void *query_output );

}
