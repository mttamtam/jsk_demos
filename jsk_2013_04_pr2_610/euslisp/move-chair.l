#!/usr/bin/env roseus
;;(ros::load-ros-manifest "jsk_perception")

;; define detection parameters befor load detection_interface.l
(defparameter *detection-topic* "/narrow_stereo/left/ObjectDetection")

;; load functions
(load "package://jsk_perception/euslisp/detection_interface.l")

;; stret program
;;(load "package://euslisp/jskeus/eus/models/room610-chair-object.l")

;;how far pr2 will be from chair center
(defparameter distance-from-chair-center 1000)

;;set variable to use for judging if grasp success or not
(defparameter *grasp-success-threshold* 10)

;;loop counter threshold for start-detect-chair
(defparameter *detect-chair-loop-threshold* 1)
;;


(defparameter *prev-chair-was* nil)


;;if you call this function, (as like (start-detect-chair))
;;*chair* will be update and move to where it would be
(defun start-detect-chair (&key (debug nil))
  (let ((loop t) (loop-counter 0) (chair-coords nil) (ret))
    (ros::roseus "objectdetection_publisher")
    (defparameter *detection-topic* "/narrow_stereo/left/ObjectDetection")
    (ros::rate 10)
      (ros::ros-info "detecting_now")
    (while loop
      (setq ret (check-detection :type "chair-center" ;; work for any object
                       :speak-name "chair object"
                       :target-object *chair*
                       :speak nil))
      (ros::spin-once)
      (if ret
	(progn
		(ros::ros-info "chair- pos info ~A before trans" *chair*)
      		(send *chair* :translate (send *pr2* :worldpos) :world)
		(ros::ros-info "chair- pos info ~A after trans" *chair*)
      		(send *pr2* :head :look-at (send(send *chair* :handle-above-rarm) :worldpos))
      		(send *ri* :angle-vector (send *pr2* :angle-vector))
	))

      (push (send *chair* :worldcoords) chair-coords)

      ;;wait a few loop
      (when (> loop-counter *detect-chair-loop-threshold*)
        (setq loop nil)	;;temp method
        )
      (inc loop-counter)
      (ros::ros-info "~d loop counter ----" loop-counter)
      (ros::sleep)
      )
    )
  )



;;after move-to, save the pos

(defun move-chair ()
  (warn "move-chair (inagaki)~%")
  (let (dest-c (grasp-success nil))

    (send *ri* :go-pos-unsafe 0.1 0 0)
    (send *pr2* :translate (float-vector 100 0 0))

    ;;reset from furuta's pose

    (send *pr2* :angle-vector (send *ri* :state :potentio-vector))
    (send *ri* :stop-grasp :rarm :wait t)

      (ros::ros-info "move to right")
  
    (send *pr2* :inverse-kinematics (send  (send (send *pr2* :rarm :end-coords) :copy-worldcoords) :translate (float-vector 0 -300 0) :world)
          :revert-if-fail nil
          :link-list (list
                      (send *pr2* :link-list (send *pr2* :rarm :end-coords :parent)))
          :move-target (list (send *pr2* :rarm :end-coords))
          :look-at-target t
          :debug-view nil
          )
    (if (boundp '*irtviewer*) (send *irtviewer* :draw-objects))
    (send *ri* :angle-vector (send *pr2* :angle-vector))
    (send *ri* :wait-interpolation)

    (setq before-pose (send *ri* :potentio-vector))

      (ros::ros-info "end move to right")
    ;; start detecting char and grasp chair
    (while (not grasp-success)
	;;setup pose
	(send *pr2* :angle-vector before-pose)
	(send *ri*  :angle-vector before-pose)
    	(send *ri* :wait-interpolation)

    	;;start-detect-chair
	(ros::ros-info "start-detect-chair")
    	(start-detect-chair)
	(ros::ros-info "end-detect-chair")
    	(send *ri* :stop-grasp :rarm)

;;    	(send *ri* :go-pos-unsafe -0.1 0 0)
;;    	(send *pr2* :translate (float-vector -100 0 0))
    	(if (boundp '*irtviewer*) (send *irtviewer* :draw-objects))

    	(send *ri* :wait-interpolation)


    	(send *pr2* :angle-vector (send *ri* :state :potentio-vector))
    	;;(send *pr2* :reset-pose) ;; to solve ik, do not  send to *ri*
        (setq handle-rarm (send (send *chair* :handle-above-rarm) :copy-worldcoords) )
    	(send *pr2* :inverse-kinematics 
	      (list (send (send  handle-rarm  :translate (float-vector -20 0 15) :world) :rotate (deg2rad 20) :y :world))
    	      :link-list (list
    	                  (send *pr2* :link-list (send *pr2* :rarm :end-coords :parent)))
    	      :move-target (list (send *pr2* :rarm :end-coords))
    	      :revert-if-fail nil
    	      :look-at-target t
              :debug-view nil
    	      )
    
    	(if (boundp '*irtviewer*) (send *irtviewer* :draw-objects))
    	(send *ri* :angle-vector (send *pr2* :angle-vector))
    	(send *ri* :wait-interpolation)

	(send *pr2* :inverse-kinematics (send  (send (send *pr2* :rarm :end-coords) :copy-worldcoords) :translate (float-vector 0 0 -40) :world)
              :link-list (list
                          (send *pr2* :link-list (send *pr2* :rarm :end-coords :parent)))
              :move-target (send *pr2* :rarm :end-coords)
              :revert-if-fail nil
              :look-at-target t
              :debug-view nil
              )


    	(send *ri* :angle-vector (send *pr2* :angle-vector))
    	(send *ri* :wait-interpolation)


	;;check if grasp is success
	(setq grip_r_dist (send *ri* :start-grasp :rarm))
	(send *ri* :update-robot-state)
	(setq grip_r_dist (send *ri* :robot :r_gripper_joint :joint-angle))

    	(send *ri* :wait-interpolation)
	(ros::ros-info "~d gripper distance" grip_r_dist)
	(when (> grip_r_dist *grasp-success-threshold*)
		(setq grasp-success t)
		)
    )
    (ros::ros-info "end catch chair")

    (setq *prev-chair-was* (send *chair* :copy-worldcoords))



    ;;(break)

    ;;-------------------------------------------------------PULL PART---------------------------------------------------;;;;
    (ros::ros-info "PULL PART...")


    (send (send *pr2* :r_wrist_roll_link) :assoc *chair*)
    (send *ri* :angle-vector (send *pr2* :angle-vector))
    (send *ri* :wait-interpolation)



    (send *ri* :go-pos-unsafe -0.3 0 0)
    (send *pr2* :translate (float-vector -300 0 0))
    
    (send *pr2* :angle-vector (send *ri* :state :potentio-vector))
    (send *ri* :wait-interpolation)

    (send (send *pr2* :r_wrist_roll_link) :dissoc *chair*)


    (setq back-legs-center (make-cascoords :coords (send *chair* :worldcoords)))
    (send back-legs-center :locate (float-vector -250 0 0))
    (send back-legs-center :assoc *chair*)
    (objects (list *room610* *pr2* (send *chair* :worldcoords) back-legs-center))

    (setq dest-c (make-cascoords :coords (send (send *pr2* :rarm :end-coords) :worldcoords)))
    (send back-legs-center :assoc dest-c)

    (setq angle-vector-list nil)
    (dotimes (i 9)
      (send (send back-legs-center :rotate (deg2rad -2) :y) :translate (float-vector -5 0 3) *pr2*)
      (send *pr2* :inverse-kinematics dest-c
	    :link-list (list
			(send *pr2* :link-list (send *pr2* :rarm :end-coords :parent)))
	    :move-target (list (send *pr2* :rarm :end-coords))
	    :look-at-target t
	    :revert-if-fail nil
            :debug-view nil
	    )
      (if (boundp '*irtviewer*) (send *irtviewer* :draw-objects))
      (push (send *pr2* :angle-vector) angle-vector-list)
      )

    (setq angle-vector-list (reverse angle-vector-list))

    (send *ri* :angle-vector-sequence angle-vector-list (make-sequence 'list (length angle-vector-list) :initial-element 300))
    (send *ri* :wait-interpolation)

    (send back-legs-center :dissoc *chair*)


    ;;-------------------------------------------------------MOVE PART---------------------------------------------------;;;;
    (ros::ros-info "Move PART...")


    (send (send *pr2* :r_wrist_roll_link) :assoc *chair*)


    (send *ri* :go-pos-unsafe -0.2 -0 0) ;;10
    ;;(send *pr2* :rotate (deg2rad -30) :z)
    (send *pr2* :translate (float-vector -200 -0 0))
    ;;(send *pr2* :rotate (deg2rad 10) :z)
    (if (boundp '*irtviewer*) (send *irtviewer* :draw-objects))

    (send *ri* :wait-interpolation)


    ;; backword
    (send *ri* :go-pos-unsafe -1.4 -0.3 -10) ;;-40
    ;;(send *pr2* :rotate (deg2rad -30) :z)
    (send *pr2* :translate (float-vector -1400 -300 0))
    (send *pr2* :rotate (deg2rad -10) :z)

    (send (send *pr2* :r_wrist_roll_link) :dissoc *chair*)

    (if (boundp '*irtviewer*) (send *irtviewer* :draw-objects))
    (send *ri* :wait-interpolation)


    ;;-------------------------------------------------------RELEASE PART---------------------------------------------------;;;;
    (ros::ros-info "Release PART...")

    (setq back-legs-center (make-cascoords :coords (send *chair* :worldcoords)))
    (send back-legs-center :locate (float-vector -250 0 0))
    (send back-legs-center :assoc *chair*)
    (objects (list *room610* *pr2* (send *chair* :worldcoords) back-legs-center))

    (setq dest-c (make-cascoords :coords (send (send *pr2* :rarm :end-coords) :worldcoords)))
    (send back-legs-center :assoc dest-c)

    (setq angle-vector-list nil)
    (dotimes (i 9)
      (send (send back-legs-center :rotate (deg2rad 2) :y) :translate (float-vector 5 0 -3) *pr2*)
      (send *pr2* :inverse-kinematics dest-c
	    :link-list (list
			(send *pr2* :link-list (send *pr2* :rarm :end-coords :parent)))
	    :move-target (list (send *pr2* :rarm :end-coords))
	    :look-at-target t
	    :revert-if-fail nil
            :debug-view nil
	    )
      (if (boundp '*irtviewer*) (send *irtviewer* :draw-objects))
      (push (send *pr2* :angle-vector) angle-vector-list)
      )

    (setq angle-vector-list (reverse angle-vector-list))

    (send *ri* :angle-vector-sequence angle-vector-list (make-sequence 'list (length angle-vector-list) :initial-element 300))
    (send *ri* :wait-interpolation)


    (send back-legs-center :dissoc *chair*)
    (send (send *pr2* :r_wrist_roll_link) :assoc *chair*)

    (send *ri* :go-pos-unsafe -0.2 -0 0) ;;10
    (send *pr2* :translate (float-vector -200 -0 0))
    (send *ri* :wait-interpolation)


    
    (send (send *pr2* :r_wrist_roll_link) :dissoc *chair*)
    (send *ri* :stop-grasp :rarm)
    (send *ri* :wait-interpolation)

    (send *pr2* :rarm :move-end-pos (float-vector -100 0 0))
    (if (boundp '*irtviewer*) (send *irtviewer* :draw-objects))
    (send *ri* :angle-vector (send *pr2* :angle-vector) 2000)
    (send *ri* :wait-interpolation)


    (send *pr2* :rarm :move-end-pos (float-vector 0 200 0))
    (if (boundp '*irtviewer*) (send *irtviewer* :draw-objects))
    (send *ri* :angle-vector (send *pr2* :angle-vector) 2000)
    (send *ri* :wait-interpolation)


    ;;-------------------------------------------------------REMEMBER PART---------------------------------------------------;;;;
    (ros::ros-info "Now Remember...")


    ;;save the place where robot was
    (ros::ros-info "Next get moved chair spot ")
    (setq *moved-chair-spot* (get-moved-chair-back-spot))

    ))


;; calc where pr2 should go next time when pr2 push back chair
(defun get-moved-chair-back-spot ()
  (let (copy-chair)
    ;;subscribe and update *chair*
    (start-detect-chair)
    
    ;;get chair info
    (setq copy-chair (send *chair* :copy-worldcoords))

    ;;move copy-chair along with x axis on local coords
    (send copy-chair :translate (float-vector (* distance-from-chair-center -1) -100 0))

    (objects (list *room610* *pr2* (send *chair* :worldcoords) copy-chair))
    (if (boundp '*irtviewer*) (send *irtviewer* :draw-objects))


    ;;return the spot
    copy-chair
	)
)


(defun move-back-chair ()
 (let ((grasp-success nil))
     (setq before-pose (send *ri* :potentio-vector))

    ;; start detecting char and grasp chair
    (while (not grasp-success)
        ;;setup pose
        (send *pr2* :angle-vector before-pose)
        (send *ri*  :angle-vector before-pose)
        (send *ri* :wait-interpolation)

        ;;start-detect-chair
        (ros::ros-info "start-detect-chair")
        (start-detect-chair)
        (ros::ros-info "end-detect-chair")
        (send *ri* :stop-grasp :rarm)

  ;;cache above pos phase---------------------------------------------------------------------------------;;
 (send *pr2* :angle-vector (send *ri* :state :potentio-vector))
    ;;(send *pr2* :reset-pose) ;; to solve ik, do not  send to *ri*
    (send *ri* :stop-grasp :rarm :wait t)
    (send *pr2* :inverse-kinematics (list (send (send (send (send *chair* :handle-above-rarm) :copy-worldcoords) :translate  (float-vector -20 0 25) (send *chair* :worldcoords)) :rotate (deg2rad 20) :y (send *chair* :worldcoords)))
          :link-list (list
                      (send *pr2* :link-list (send *pr2* :rarm :end-coords :parent)))
          :move-target (list (send *pr2* :rarm :end-coords))
          :revert-if-fail nil
          :look-at-target t
          :debug-view nil
          )

    (if (boundp '*irtviewer*) (send *irtviewer* :draw-objects))
    (send *ri* :angle-vector (send *pr2* :angle-vector))
    (send *ri* :wait-interpolation)


    (send *pr2* :inverse-kinematics (send  (send (send *pr2* :rarm :end-coords) :copy-worldcoords) :translate (float-vector 0 0 -50) :world)
              :link-list (list
                          (send *pr2* :link-list (send *pr2* :rarm :end-coords :parent)))
              :move-target (send *pr2* :rarm :end-coords)
              :revert-if-fail nil
              :look-at-target t
              :debug-view nil
              )


        (send *ri* :angle-vector (send *pr2* :angle-vector))
        (send *ri* :wait-interpolation)


        ;;check if grasp is success
        (setq grip_r_dist (send *ri* :start-grasp :rarm))
        (send *ri* :update-robot-state)
        (setq grip_r_dist (send *ri* :robot :r_gripper_joint :joint-angle))

        (send *ri* :wait-interpolation)
        (ros::ros-info "~d gripper distance" grip_r_dist)
        (when (> grip_r_dist *grasp-success-threshold*)
                (setq grasp-success t)
                )
    )
    ;; -------- pr2 catch chair !!!!! -------------------------
    (ros::ros-info "--PR2 Catch IT !!!!!--")

    (send (send *pr2* :r_wrist_roll_link) :assoc *chair*)
    (send *ri* :angle-vector (send *pr2* :angle-vector))
    (send *ri* :wait-interpolation)

    (send *ri* :go-pos-unsafe -0.2 -0.1 0) ;;10
    (send *pr2* :translate (float-vector -200 -100 0))
    (send *ri* :wait-interpolation)

    (send *pr2* :inverse-kinematics (send  (send (send *pr2* :rarm :end-coords) :copy-worldcoords) :translate (float-vector 0 0 50) :world)
              :link-list (list
                          (send *pr2* :link-list (send *pr2* :rarm :end-coords :parent)))
              :move-target (send *pr2* :rarm :end-coords)
              :revert-if-fail nil
              :look-at-target t
              :debug-view nil
              )


        (send *ri* :angle-vector (send *pr2* :angle-vector))
        (send *ri* :wait-interpolation)


  ;;push and move phase---------------------------------------------------------------------------------;;
    (ros::ros-info "--Push and Move PART!--")
    (setq now-chair-pos (send (send *chair* :copy-worldcoords) :worldpos))
    (setq prev-chair-pos (send *prev-chair-was* :worldpos))
    (setq diff-chair-pos (v- prev-chair-pos now-chair-pos))
    (ros::ros-info "we will move ~A" diff-chair-pos)

    (setq scale-diff-chair-pos (scale 0.001 diff-chair-pos))

    ;; add offset and do go-pos
    (setq offset-y 0.1)
    (send *ri* :go-pos-unsafe (elt scale-diff-chair-pos 0) (+ (elt scale-diff-chair-pos 1) offset-y) (elt scale-diff-chair-pos 2)) ;;-40
    (send *pr2* :translate diff-chair-pos)
    (send *pr2* :rotate (deg2rad 10) :z)

    (if (boundp '*irtviewer*) (send *irtviewer* :draw-objects))
    (send *ri* :wait-interpolation)


    (send *ri* :go-pos-unsafe -0.2 -0 0) ;;10
    (send *pr2* :translate (float-vector -200 -0 0))
    (send *ri* :wait-interpolation)


  ;;end push and release chair -------------------------------------------------------------------------;;
    (ros::ros-info "--End Push and Release PART!--")

    (send (send *pr2* :r_wrist_roll_link) :dissoc *chair*)
    (send *ri* :stop-grasp :rarm)
    (send *ri* :wait-interpolation)

    (send *pr2* :inverse-kinematics (send  (send (send *pr2* :rarm :end-coords) :copy-worldcoords) :translate (float-vector 0 0 100) :world)
              :link-list (list
                          (send *pr2* :link-list (send *pr2* :rarm :end-coords :parent)))
              :move-target (send *pr2* :rarm :end-coords)
              :revert-if-fail nil
              :look-at-target t
              :debug-view nil
              )


        (send *ri* :angle-vector (send *pr2* :angle-vector))
        (send *ri* :wait-interpolation)

 )
 
)
